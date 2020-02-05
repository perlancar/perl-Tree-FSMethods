package Tree::FSMethods::Org;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Code::Includable::Tree::NodeMethods;

use parent qw(Tree::FSMethods);

sub new {
    my ($class, %args) = (shift, @_);
    $args{filename_method} //= sub {
        my $node = shift;
        return undef unless $node->can("title");
        my $name = $node->title;
        $name =~ s/\[.*?\]//g;
        $name =~ s/\s{2,}/ /g;
        $name =~ s/^\s+//;
        $name =~ s/\s$//;
        $name;
    };
    if (defined $args{org_file}) {
        require Org::Parser::Tiny;
        $args{tree} = Org::Parser::Tiny->new->parse_file(
            delete $args{org_file});
    }
    if (defined $args{org_file1}) {
        require Org::Parser::Tiny;
        $args{tree1} = Org::Parser::Tiny->new->parse_file(
            delete $args{org_file1});
    }
    if (defined $args{org_file2}) {
        require Org::Parser::Tiny;
        $args{tree2} = Org::Parser::Tiny->new->parse_file(
            delete $args{org_file2});
    }
    $class->SUPER::new(%args);
}

sub _adjust_copied_nodes {
    my ($self, $nodes_to_copy, $target_node) = @_;

    say "D1: ", scalar(@$nodes_to_copy);
    my $target_level = $target_node->can("level") ? $target_node->level : 0;
    my $levels_to_increase;

    for my $node_to_copy (@$nodes_to_copy) {
        unless (defined $levels_to_increase) {
            my $node_level = $node_to_copy->can("level") ? $node_to_copy->level : 0;
            $levels_to_increase = $target_level+1 - $node_to_copy->level;
            $levels_to_increase = 0 if $levels_to_increase < 0;
        }
        next unless $levels_to_increase;
        $node_to_copy->level( $node_to_copy->level + $levels_to_increase )
            if $node_to_copy->can("level");
        Code::Includable::Tree::NodeMethods::walk(
            $node_to_copy, sub {
                my $node = shift;
                $node->level( $node->level + $levels_to_increase )
                    if $node->can("level");
            });
    }
}

1;
# ABSTRACT: Perform filesystem-like operations on Org document tree

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 use Tree::FSMethods::Org;

 my $fs = Tree::FSMethods::Org->new(
     # specify an already parsed Org document ...
     tree => $tree,
     # tree1 => $tree,
     # tree2 => $other_tree,

     # ... or request parse from a file
     org_file => "/some/path/to/file.org",
     # org_file1 => ...
     # org_file2 => ...

     # defaults to getting from title(), with "[...]" trimmed (priority like
     # "[#B]" or statistics cookie like "[20%]" or "[2/10]")
     # filename_method => 'filename',
 );


=head1 DESCRIPTION

This is a subclass of L<Tree::FSMethods> with some nicer defaults for Org
document tree produced by L<Org::Parser::Tiny>.


=head1 METHODS


=head1 SEE ALSO

L<Tree::FSMethods>
