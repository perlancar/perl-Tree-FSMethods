package Tree::FSMethods;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Code::Includable::Tree::NodeMethods;

sub new {
    my ($class, %args) = (shift, @_);
    bless \%args, $class;
}

sub ls {
    my $self = shift;

    my $filename_method = $self->{filename_method} // 'filename';

    my @res;
    for my $node (Code::Includable::Tree::NodeMethods::_children_as_list($self->{tree})) {
        push @res, $node->$filename_method;
    }
    @res;
}

1;
# ABSTRACT: Perform filesystem-like operations on object tree

=head1 SYNOPSIS

 use Tree::FSMethods;

 my $fs = Tree::FSMethods->new(
     tree => $tree,
     # filename_method => 'filename',
     # path_method     => 'path',
 );

 # list top-level (root) "files"
 my @nodes = $fs->ls("/");


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

=item * filename_method

=item * path_method

=back


=head1 SEE ALSO

L<Role::TinyCommons::Tree>
