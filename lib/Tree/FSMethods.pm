package Tree::FSMethods;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Code::Includable::Tree::NodeMethods;
use Path::Naive;
use String::Wildcard::Bash;

sub new {
    my ($class, %args) = (shift, @_);

    if ($args{tree}) {
        $args{_curpath} = "/";
        $args{_curnode} = $args{tree};
    }
    if ($args{tree1}) {
        $args{_curpath1} = "/";
        $args{_curnode1} = $args{tree1};
    }
    if ($args{tree2}) {
        $args{_curpath2} = "/";
        $args{_curnode2} = $args{tree2};
    }

    bless \%args, $class;
}

sub _cd {
    my $self = shift;
    my ($which, $path) = @_;

    my $rootnode =
        $which == 1 ? $self->{tree1} :
        $which == 2 ? $self->{tree2} : $self->{tree};
    my $curnode =
        $which == 1 ? $self->{_curnode1} :
        $which == 2 ? $self->{_curnode2} : $self->{_curnode};
    my $curpath =
        $which == 1 ? $self->{_curpath1} :
        $which == 2 ? $self->{_curpath2} : $self->{_curpath};

    die "cd: No object loaded yet" unless $curnode;

    my ($node, @path_elems, $is_abs);
    if (Path::Naive::is_abs_path($path)) {
        $node = $rootnode;
        @path_elems = ();
    } else {
        $node = $curnode;
        @path_elems = (Path::Naive::split_path($curpath));
    }

    for my $path_elem (Path::Naive::split_path($path)) {
        if ($path_elem eq '.') {
            next;
        } elsif ($path_elem eq '..') {
            if ($node->parent) {
                $node = $node->parent;
            }
            pop @path_elems if @path_elems;
            next;
        }
        local $self->{_curnode} = $node;
        local $self->{_curpath} = "/" . join("/", @path_elems);
        my %lsres = $self->ls();
        if ($lsres{$path_elem}) {
            $node = $lsres{$path_elem}{node};
            push @path_elems, $path_elem;
        } else {
            die "cd: No such path: ".($self->{_curpath} . ($self->{_curpath} =~ m!/\z! ? "" : "/") . $path_elem);
        }
    }

    if      ($which == 1) {
        $self->{_curnode1} = $node; $self->{_curpath1} = "/" . join("/", @path_elems);
    } elsif ($which == 2) {
        $self->{_curnode2} = $node; $self->{_curpath2} = "/" . join("/", @path_elems);
    } else {
        $self->{_curnode}  = $node; $self->{_curpath}  = "/" . join("/", @path_elems);
    }
}

sub cd {
    my ($self, $path) = @_;
    $self->_cd(0, $path);
}

sub cd1 {
    my ($self, $path) = @_;
    $self->_cd(1, $path);
}

sub cd2 {
    my ($self, $path) = @_;
    $self->_cd(2, $path);
}

sub ls {
    my $self = shift;

    my $re_wildcard;
    my $save_curnode;
    my $save_curpath;
    if (@_ && defined $_[0] && length $_[0]) {
        my $path = $_[0];
        $save_curnode = $self->{_curnode};
        $save_curpath = $self->{_curpath};
        my @path_elems = Path::Naive::normalize_path($path);
        if (@path_elems && String::Wildcard::Bash::contains_wildcard($path_elems[-1])) {
            $re_wildcard = String::Wildcard::Bash::convert_wildcard_to_re(pop @path_elems);
            $re_wildcard = qr/\A$re_wildcard\z/;
            $path = (Path::Naive::is_abs_path($path) ? "/" : "") . join("/", @path_elems);
            $path = "/" if $path eq '';
        }
        $self->cd($path);
    }

    my %nodes_by_name;
    my $order = 0;

  NODE:
    for my $node (Code::Includable::Tree::NodeMethods::_children_as_list($self->{_curnode})) {
        my $name;
      ASSIGN_NAME: {
            my @methods;
            if (defined $self->{filename_method}) {
                push @methods, $self->{filename_method};
            }
            push @methods, "filename", "title";

            for my $method (@methods) {
                if (ref $method eq 'CODE') {
                    $name = $method->($node);
                } elsif ($node->can($method)) {
                    $name = $node->$method;
                }
                last if defined $name;
            }
            last if defined $name;

            $name = "$node";
        }

      HANDLE_INVALID: {
            if ($name eq '') {
                $name = "unnamed";
            } elsif ($name eq '.') {
                $name = '.(dot)';
            } elsif ($name eq '.') {
                $name = '..(dot-dot)';
            }
            $name =~ s!/!_!g;
            $name = substr($name, 0, 250) if length $name > 250;
        }

      HANDLE_DUPLICATES: {
            last unless exists $nodes_by_name{$name};
            my $suffix = "2";
            while (1) {
                my $new_name = "$name.$suffix";
                do { $name = $new_name; last }
                    unless exists $nodes_by_name{$new_name};
                $suffix++;
                die "Too many duplicate names ($name)" if $suffix >= 9999;
            }
        }

      FILTER_WILDCARD: {
            last unless $re_wildcard;
            next NODE unless $name =~ $re_wildcard;
        }

        $nodes_by_name{$name} = {
            order => $order,
            name  => $name,
            node  => $node,
            path  => $self->{_curpath} .
                ($self->{_curpath} eq '/' ? '' : '/') . $name,
        };
        $order++;
    }

    if (defined $save_curnode) {
        $self->{_curnode} = $save_curnode;
        $self->{_curpath} = $save_curpath;
    }

    %nodes_by_name;
}

sub get {
    my $self = shift;
    my $path = shift;

    my ($dir, $file) = $path =~ m!(.*/)?(.*)!;
    $dir //= ".";

    my %ls_res = $self->ls($dir);
    if ($ls_res{$file}) {
        return $ls_res{$file}{node};
    } else {
        die "get: No such file '$file' in directory '$dir'";
    }
}

sub ls1 {
    my $self = shift;
    local $self->{_curnode} = $self->{_curnode1};
    local $self->{_curpath} = $self->{_curpath1};
    $self->ls(@_);
}

sub _cwd {
    my $self = shift;
    my $which = shift;
    $which == 1 ? $self->{_curpath1} :
        $which == 2 ? $self->{_curpath2} : $self->{_curpath};
}

sub cwd {
    my $self = shift;
    $self->_cwd(0);
}

sub cwd1 {
    my $self = shift;
    $self->_cwd(1);
}

sub cwd2 {
    my $self = shift;
    $self->_cwd(2);
}

sub _cp_or_mv {
    my $self = shift;
    my $which = shift;
    my ($path1, $path2) = @_;

    length($path1)     or die "Please specify path1";
    $self->{_curnode1} or die "Please load tree1 first";
    length($path2)     or die "Please specify path2";
    $self->{_curnode2} or die "Please load tree2 first";

    my $path1_is_abs = Path::Naive::is_abs_path($path1);
    my @path1_elems = Path::Naive::normalize_path($path1);
    die "$which: Must specify source files" unless @path1_elems;
    my $path1_has_wildcard = String::Wildcard::Bash::contains_wildcard($path1_elems[-1]);
    my %ls_res;
    if ($path1_has_wildcard) {
        %ls_res = $self->ls1($path1);
    } else {
        my $wanted = pop @path1_elems;
        $path1 = ($path1_is_abs ? "/" : "./") . join("/", @path1_elems);
        %ls_res = $self->ls1($path1);
        for (keys %ls_res) {
            delete $ls_res{$_} unless $_ eq $wanted;
        }
    }
    die "$which: No matching source nodes to copy/move from" unless keys %ls_res;

    my $save_curnode2 = $self->{_curnode2};
    my $save_curpath2 = $self->{_curpath2};
    $self->cd2($path2);

    my @nodes_to_copy_or_move = map { $ls_res{$_}{node} }
        sort { $ls_res{$a}{order} <=> $ls_res{$b}{order} } keys %ls_res;

    if ($which eq 'cp') {
        if ($self->can("before_cp")) {
            $self->before_cp(\@nodes_to_copy_or_move, $self->{_curnode2});
        }
    } elsif ($which eq 'mv') {
        if ($self->can("before_mv")) {
            $self->before_mv(\@nodes_to_copy_or_move, $self->{_curnode2});
        }
    } else {
        die "BUG: which must be cp/mv";
    }

    push @{ $self->{_curnode2}->{children} }, @nodes_to_copy_or_move;
    for my $node (@nodes_to_copy_or_move) {
        $node->parent( $self->{_curnode2} );
    }

    if ($which eq 'mv') {
        # remove the nodes from their parents
        for my $node (@nodes_to_copy_or_move) {
            Code::Includable::Tree::NodeMethods::remove($node);
        }
    }

    $self->{_curnode2} = $save_curnode2;
    $self->{_curpath2} = $save_curpath2;
}

sub cp {
    my $self = shift;
    $self->_cp_or_mv('cp', @_);
}

sub mv {
    my $self = shift;
    $self->_cp_or_mv('mv', @_);
}

sub rm {
    my $self = shift;
    my $path = shift;

    length($path)     or die "Please specify path";
    $self->{_curnode} or die "Please load tree first";

    my $path_is_abs = Path::Naive::is_abs_path($path);
    my @path_elems  = Path::Naive::normalize_path($path);
    die "rm: Must specify files" unless @path_elems;
    my $path_has_wildcard = String::Wildcard::Bash::contains_wildcard($path_elems[-1]);
    my %ls_res;
    if ($path_has_wildcard) {
        %ls_res = $self->ls($path);
    } else {
        my $wanted = pop @path_elems;
        $path = ($path_is_abs ? "/" : "./") . join("/", @path_elems);
        %ls_res = $self->ls($path);
        for (keys %ls_res) {
            delete $ls_res{$_} unless $_ eq $wanted;
        }
    }
    die "rm: No matching files to delete" unless keys %ls_res;

    my @nodes_to_rm = map { $ls_res{$_}{node} }
        sort { $ls_res{$a}{order} <=> $ls_res{$b}{order} } keys %ls_res;
    for my $node (@nodes_to_rm) {
        Code::Includable::Tree::NodeMethods::remove($node);
    }
}

1;
# ABSTRACT: Perform filesystem-like operations on object tree(s)

=head1 SYNOPSIS

 use Tree::FSMethods;

 my $fs = Tree::FSMethods->new(
     tree => $tree,
     # tree1 => $tree,
     # tree2 => $other_tree,
     # filename_method => 'filename',
 );

Listing files:

 # list top-level (root)
 my %nodes = $fs->ls; # ("foo"=>{...}, "bar"=>{...}, "baz"=>{...})

 # specify path. will list all nodes under /proj.
 my %nodes = $fs->ls("/proj");

 # specify wildcard. will list all nodes under /proj which has 'perl' in their
 # names.
 my %nodes = $fs->ls("/proj/*perl*");


=head1 DESCRIPTION


=head1 METHODS

=head2 new

Usage:

 my $fs = Tree::FSMethods->new(%args);

Arguments:

=over

=item * tree

Required. Object. The tree node object. A tree node object is any regular Perl
object satisfying the following criteria: 1) it supports a C<parent> method
which should return a single parent node object, or undef if object is the root
node); 2) it supports a C<children> method which should return a list (or an
arrayref) of children node objects (where the list/array will be empty for a
leaf node). Note: you can use L<Role::TinyCommons::Tree::Node> to enforce this
requirement.

=item * tree1

See C<tree>.

Optional. Used for some operations: L</cp>, L</mv>.

=item * tree2

See C<tree>.

Optional. Used for some operations: L</cp>, L</mv>.

=item * filename_method

Optional. String or coderef.

By default, will call C<filename> method on tree node to get the filename of a
node. If that method is not available, will use C<title> method. If that method
is also not available, will use its "hash address" given by the stringification,
e.g. "HASH(0x56242e558740)" or "Foo=HASH(0x56242e558740)".

If C<filename_method> is specified and is a string, will use the method
specified by it.

If C<filename_method> is a coderef, will call the coderef, passing the tree node
as argument and expecting filename as the return value.

If filename is empty, will use "unnamed".

If filename is non-unique (in the same "directory"), will append ".2", ".3",
".4" (and so on) suffixes.

=back

=head2 cd

Usage:

 $fs->cd($path);

Change working directory. Dies on failure.

=head2 cd1

Usage:

 $fs->cd1($path);

Change working directory (for C<tree1> object).

=head2 cd2

Usage:

 $fs->cd2($path);

Change working directory (for C<tree2> object).

=head2 cwd

Usage:

 my $cwd = $fs->cwd;

Return current working directory.

=head2 cwd1

Usage:

 my $cwd = $fs->cwd1;

Return current working directory (for C<tree1> object).

=head2 cwd2

Usage:

 my $cwd = $fs->cwd2;

Return current working directory (for C<tree2> object).

=head2 ls

Usage:

 my %res = $fs->ls( [ $path ]);

Dies on failure (e.g. can't cd to specified path).

=head2 cp

Usage:

 $fs->cp($path1, $path2);

Copies nodes from C<tree1> to C<tree2>. Dies on failure (e.g. can't find source
or target path).

Examples:

 $fs->cp("proj/*perl*", "proj/");

This will set nodes under C<proj/> in the source tree matching wildcard
C<*perl*> to C<proj/> in the target tree.

=head2 mv

Usage:

 $fs->mv($path1, $path2);

Moves nodes from C<tree1> to C<tree2>. Dies on failure (e.g. can't find source
or target path).


=head1 SEE ALSO

L<Role::TinyCommons::Tree>
