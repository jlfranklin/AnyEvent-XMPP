package Net::XMPP2::Disco;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

=head1 NAME

Net::XMPP2::Disco - A service discovery manager class for XEP-0030

=head1 SYNOPSIS

   package foo;
   use Net::XMPP2::Disco;

   my $con = Net::XMPP2::IM::Connection->new (...);
   ...
   my $disco = Net::XMPP2::Disco->new (connection => $con);

   $disco->request_items ('romeo@montague.net',
      node => 'http://jabber.org/protocol/tune',
      cb   => sub {
         my ($disco, $response, $error) = @_;
         if ($error) { print "ERROR".$error->string."\n" }
         else {
            ... do something with the $response ...
         }
      }
   );

=head1 DESCRIPTION

This module represents a service discovery manager class.
You make instances of this class and get a handle to send
discovery requests like described in XEP-0030.

It also allows you to setup a disco-info/items tree
that others can walk and also lets you publish disco information.

=head1 METHODS

=head2 new (%args)

Creates a new disco handle. Possible keys for the C<%args> hash are:

=over 4

=item connection => $connection

The connection this handle will send the requests with and
answer requests.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;
   my $con = $self->{connection};

   $self->set_identity (client => console => 'Net::XMPP2');

   $self->{cb_id} =
      $con->reg_cb (
         iq_get_request_xml => sub {
            my ($con, $node, $handled_ref) = @_;
            return 1 if $$handled_ref;

            if ($self->handle_disco_query ($node)) {
               $$handled_ref = 1;
            }

            1
         }
      );
}

=head2 set_identity ($category, $type, $name)

This sets the identity of the top info node.
The default is: C<$category = "client">, C<$type = "console">
and C<$name = "Net::XMPP2">.

C<$name> is optional and can be undef.

For a list of valid identites look at:

   http://www.xmpp.org/registrar/disco-categories.html

Valid identity types for C<$category = "client"> may be:

   bot
   console
   handheld
   pc
   phone
   web

=cut

sub set_identity {
   my ($self, $category, $type, $name) = @_;
   $self->{iden}->{cat}  = $category;
   $self->{iden}->{type} = $type;
   $self->{iden}->{name} = $name;
}


=head2 enable_feature ($uri)

This method enables the feature C<$uri>, where C<$uri>
should be one of the values from the B<Name> column on:

   http://www.xmpp.org/registrar/disco-features.html

These features are enabled by default:

   http://jabber.org/protocol/disco#info
   http://jabber.org/protocol/disco#items

=cut

sub enable_feature {
   my ($self, $feature) = @_;
   $self->{feat}->{$feature} = 1
}

=head2 disable_feature ($uri)

This method enables the feature C<$uri>, where C<$uri>
should be one of the values from the B<Name> column on:

   http://www.xmpp.org/registrar/disco-features.html

These features are enabled by default:

   http://jabber.org/protocol/disco#info
   http://jabber.org/protocol/disco#items

=cut

sub disable_feature {
   my ($self, $feature) = @_;
   delete $self->{feat}->{$feature}
}

sub write_feature {
   my ($self, $w, $var) = @_;

   $w->emptyTag ([xmpp_ns ('disco_info'), 'feature'], var => $var);
}

sub write_identity {
   my ($self, $w, $cat, $type, $name) = @_;

   $w->emptyTag ([xmpp_ns ('disco_info'), 'identity'],
      category => $cat,
      type     => $type,
      (defined $name ? (name => $name) : ())
   );
}

sub handle_disco_query {
   my ($self, $node) = @_;
   warn "HANDL\n";

   if ($node->find_all ([qw/disco_info query/])) {
      $self->{connection}->reply_iq_result (
         $node, sub {
            my ($w) = @_;

            if ($node->attr ('node')) {
               $w->addPrefix (xmpp_ns ('disco_info'), '');
               $w->emptyTag ([xmpp_ns ('disco_info'), 'query']);

            } else {
               $w->addPrefix (xmpp_ns ('disco_info'), '');
               $w->startTag ([xmpp_ns ('disco_info'), 'query']);
                  $self->write_identity ($w,
                     $self->{iden}->{cat},
                     $self->{iden}->{type},
                     $self->{iden}->{name},
                  );
                  $self->write_feature ($w, 'http://jabber.org/protocol/disco#info');
                  $self->write_feature ($w, 'http://jabber.org/protocol/disco#items');
               $w->endTag;
            }
         }
      );

      return 1

   } elsif ($node->find_all ([qw/disco_items query/])) {
      $self->{connection}->reply_iq_result (
         $node, sub {
            my ($w) = @_;

            if ($node->attr ('node')) {
               $w->addPrefix (xmpp_ns ('disco_items'), '');
               $w->emptyTag ([xmpp_ns ('disco_items'), 'query']);

            } else {
               $w->addPrefix (xmpp_ns ('disco_items'), '');
               $w->emptyTag ([xmpp_ns ('disco_items'), 'query']);
            }
         }
      );

      return 1
   }

   0
}

sub DESTROY {
   my ($self) = @_;
   $self->{connection}->unreg_cb ($self->{cb_id})
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;