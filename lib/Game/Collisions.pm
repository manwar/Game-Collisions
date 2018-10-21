# Copyright (c) 2018  Timm Murray
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice, 
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright 
#       notice, this list of conditions and the following disclaimer in the 
#       documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
package Game::Collisions;

use v5.14;
use warnings;
use List::Util ();

use Game::Collisions::AABB;

# ABSTRACT: Collision detection in 2D space


sub new
{
    my ($class) = @_;
    my $self = {
        root_aabb => undef,
        complete_aabb_list => [],
    };
    bless $self => $class;


    return $self;
}


sub make_aabb
{
    my ($self, $args) = @_;
    my $aabb = Game::Collisions::AABB->new( $args );
    $self->_add_aabb( $aabb );
    return $aabb;
}

sub get_collisions
{
    my ($self) = @_;
    my @aabbs_to_check = @{ $self->{complete_aabb_list} };
    my @collisions;

    foreach my $aabb (@aabbs_to_check) {
        push @collisions => $self->get_collisions_for_aabb( $aabb );
    }

    return @collisions;
}

sub get_collisions_for_aabb
{
    my ($self, $aabb) = @_;
    return () if ! defined $self->{root_aabb};
    my @collisions;

    my @nodes_to_check = ($self->{root_aabb});
    while( @nodes_to_check ) {
        my $check_node = shift @nodes_to_check;
        my $does_collide = $aabb->does_collide( $check_node );

        if(! $does_collide ) {
            # No collision, do nothing
        }
        elsif( $does_collide && $check_node->is_branch_node ) {
            # Branch node, decend further
            push @nodes_to_check,
                $check_node->left_node,
                $check_node->right_node;
        }
        else {
            # Leaf node, add to collisions
            push @collisions, [ $aabb, $check_node ];
        }
    }

    return @collisions;
}


sub _add_aabb
{
    my ($self, $new_node) = @_;
    if(! defined $self->{root_aabb} ) {
        $self->{root_aabb} = $new_node;
        push @{ $self->{complete_aabb_list} }, $new_node;
        return;
    }

    my $best_sibling = $self->{root_aabb}->find_best_sibling_node( $new_node );

    my $min_x = List::Util::min( $new_node->x, $best_sibling->x );
    my $min_y = List::Util::min( $new_node->y, $best_sibling->y );

    my $new_branch = $self->_new_meta_aabb({
        x => $min_x,
        y => $min_y,
        length => 1,
        height => 1,
    });

    my $old_parent = $best_sibling->parent;
    $new_branch->set_left_node( $new_node );
    $new_branch->set_right_node( $best_sibling );

    if(! defined $old_parent ) {
        # Happens when the root is going to be the new sibling. In this case, 
        # create a new node for the root.
        $self->{root_aabb} = $new_branch;
    }
    else {
        my $set_method = $best_sibling == $old_parent->left_node
            ? "set_left_node"
            : "set_right_node";
        $old_parent->$set_method( $new_branch );
    }

    $new_branch->resize_all_parents;
    push @{ $self->{complete_aabb_list} }, $new_node;
    return;
}

sub _new_meta_aabb
{
    my ($self, $args) = @_;
    my $aabb = Game::Collisions::AABB->new( $args );
    return $aabb;
}


1;
__END__


=head1 NAME

  Game::Collisions - Collision detection

=head1 SYNOPSIS

    my $collide = Game::Collisions->new;

    my $box1 = $collide->make_aabb({
        x => 0,
        y => 0,
        length => 1,
        height => 1,
    });
    my $box2 = $collide->make_aabb({
        x => 2,
        y => 0,
        length => 1,
        height => 1,
    });

    if( $box1->does_collide( $box2 ) ) {
        say "Collides";
    }

    my @collisions = $collide->get_collisions;

=head1 DESCRIPTION

Checks for collisions between objects. Can check for a collision between 
two specific objects, or generate the collisions between all objects in the 
system.

=head2 What's an Axis-Aligned Bounding Box (AABB)?

A rectangle that's aligned with the x/y axis (in other words, not rotated). 
It's common to have the box surround (bound) the entire area of a more complex 
object. Since it's cheap to check for AABB collisions, it's useful to start 
there, and only then use more expensive algorthims to check more accurately.

=head1 METHODS

=head2 new

Constructor.

=head2 make_aabb

    my $box1 = $collide->make_aabb({
        x => 0,
        y => 0,
        length => 1,
        height => 1,
    });

Creates an AABB at the specified x/y coords, in the specified dimentions.

=head2 get_collisions

Returns a list of all collisions in the system's current state. Each element 
is an array ref containing the two objects that intersect.

=head2 get_collisions_for_aabb

  get_collisions_for_aabb( $aabb )

Returns a list of all collisions against the specific AABB.  Each element 
is an array ref containing the two objects that intersect.


=head1 LICENSE

Copyright (c) 2018  Timm Murray
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright 
      notice, this list of conditions and the following disclaimer in the 
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.

=cut
