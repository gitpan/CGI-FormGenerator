=head1 NAME

CGI::WebUserInput - Perl module that gathers, parses, and manages user input
data, including query strings, posts, searches, cookies, and shell arguments, 
as well as providing cleaner access to many environment variables.

=cut

######################################################################

package CGI::WebUserInput;
require 5.004;

# Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
# free software; you can redistribute it and/or modify it under the same terms as
# Perl itself.  However, I do request that this copyright information remain
# attached to the file.  If you modify this module and redistribute a changed
# version then please attach a note listing the modifications.

use strict;
use vars qw($VERSION @ISA);
$VERSION = '0.9';

######################################################################

=head1 DEPENDENCIES

=head2 Perl Version

	5.004

=head2 Standard Modules

	I<none>

=head2 Nonstandard Modules

	CGI::HashOfArrays

=cut

######################################################################

use CGI::HashOfArrays;

######################################################################

=head1 SYNOPSIS

I<This POD is coming when I get the time to write it.>

=head1 DESCRIPTION

I<This POD is coming when I get the time to write it.>

=head1 SYNTAX

This class does not export any functions or methods, so you need to call them
using indirect notation.  This means using B<Class-E<gt>function()> for functions
and B<$object-E<gt>method()> for methods.

=head1 FUNCTIONS AND METHODS

I<This POD is coming when I get the time to write it.>

	new([ USER_INPUT ])
	initialize([ USER_INPUT ])

	user_cookie_str()
	user_query_str()
	user_post_str()
	user_offline_str()
	is_oversize_post()

	request_method()
	content_length()

	server_name()
	virtual_host()
	server_port()
	script_name()

	http_referer()

	remote_addr()
	remote_host()
	remote_user()
	user_agent()

	is_mod_perl()

	base_url()
	self_url()
	self_post([ LABEL ])
	self_html([ LABEL ])

	user_cookie([ NEW_VALUES ])
	user_cookie_string()
	user_cookie_param( KEY[, NEW_VALUES] )

	user_input([ NEW_VALUES ])
	user_input_string()
	user_input_param( KEY[, NEW_VALUE] )
	user_input_keywords()

	persistant_user_input_params([ NEW_VALUES ])
	persistant_user_input_string()
	persistant_user_input_param( KEY[, NEW_VALUES] )
	persistant_url()

	parse_url_encoded_cookies( DO_LC_KEYS, ENCODED_STRS )
	parse_url_encoded_queries( DO_LC_KEYS, ENCODED_STRS )

=cut

######################################################################

# Names of properties for objects of this class are declared here:

# These properties are set only once because they correspond to user 
# input that can only be gathered prior to this program starting up.
my $KEY_INITIAL_UI = 'ui_initial_user_input';
	my $IKEY_COOKIE   = 'user_cookie_str'; # cookies from browser
	my $IKEY_QUERY    = 'user_query_str';  # query str from browser
	my $IKEY_POST     = 'user_post_str';   # post data from browser
	my $IKEY_OFFLINE  = 'user_offline_str'; # shell args / redirect
	my $IKEY_OVERSIZE = 'is_oversize_post'; # true if cont len >max

# These properties are not recursive, but are unlikely to get edited
my $KEY_USER_COOKIE = 'ui_user_cookie'; # settings from browser cookies
my $KEY_USER_INPUT  = 'ui_user_input';  # settings from browser query/post

# These properties keep track of important user/pref data that should
# be returned to the browser even if not recognized by subordinates.
my $KEY_PERSIST_QUERY  = 'ui_persist_query';  # which qp persist for session
	# this is used only when constructing new urls, and it stores just 
	# the names of user input params whose values we are to return.

# Constant values used in this class go here:

my $MAX_CONTENT_LENGTH = 100_000;  # currently limited to 100 kbytes
my $UIP_KEYWORDS = '.keywords';  # user input param for ISINDEX queries

######################################################################

sub new {
	my $starter = shift( @_ );  # starter is either object or class
	my $self = {};
	bless( $self, ref($starter) || $starter );
	$self->{$KEY_INITIAL_UI} = ref($starter) ? 
		$starter->{$KEY_INITIAL_UI} : $self->get_initial_user_input();
	$self->initialize( @_ );
	return( $self );
}

######################################################################
# This collects user input, and should only be called once by a program
# for the reason that multiple POST reads from STDIN can cause a hang 
# if the extra data isn't there.

sub get_initial_user_input {
	my %iui = ();

	$iui{$IKEY_COOKIE} = $ENV{'HTTP_COOKIE'} || $ENV{'COOKIE'};
	
	if( $ENV{'REQUEST_METHOD'} =~ /^(GET|HEAD|POST)$/ ) {
		$iui{$IKEY_QUERY} = $ENV{'QUERY_STRING'};
		
		if( $ENV{'CONTENT_LENGTH'} <= $MAX_CONTENT_LENGTH ) {
			read( STDIN, $iui{$IKEY_POST}, $ENV{'CONTENT_LENGTH'} );
			chomp( $iui{$IKEY_POST} );
		} else {  # post too large, error condition, post not taken
			$iui{$IKEY_OVERSIZE} = $MAX_CONTENT_LENGTH;
		}

	} elsif( @ARGV ) {
		$iui{$IKEY_OFFLINE} = $ARGV[0];

	} else {
		print STDERR "offline mode: enter query string on standard input\n";
		print STDERR "it must be query-escaped and all one one line\n";
		$iui{$IKEY_OFFLINE} = <STDIN>;
		chomp( $iui{$IKEY_OFFLINE} );
	}

	return( \%iui );
}

######################################################################

sub initialize {
	my ($self, $user_input) = @_;
	
	$self->{$KEY_USER_COOKIE} = $self->parse_url_encoded_cookies( 1, 
		$self->user_cookie_str() 
	);
	$self->{$KEY_USER_INPUT} = $self->parse_url_encoded_queries( 1, 
		$self->user_query_str(), 
		$self->user_post_str(), 
		$self->user_offline_str() 
	);
	$self->{$KEY_PERSIST_QUERY} = {};
	
	$self->user_input( $user_input );
}

######################################################################

sub user_cookie_str  { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_COOKIE}   }
sub user_query_str   { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_QUERY}    }
sub user_post_str    { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_POST}     }
sub user_offline_str { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_OFFLINE}  }
sub is_oversize_post { $_[0]->{$KEY_INITIAL_UI}->{$IKEY_OVERSIZE} }

######################################################################

sub request_method { $ENV{'REQUEST_METHOD'} || 'GET' }
sub content_length { $ENV{'CONTENT_LENGTH'} + 0 }

sub server_name { $ENV{'SERVER_NAME'} || 'localhost' }
sub virtual_host { $ENV{'HTTP_HOST'} || $_[0]->server_name() }
sub server_port { $ENV{'SERVER_PORT'} || 80 }
sub script_name {
	my $str = $ENV{'SCRIPT_NAME'};
	$str =~ tr/+/ /;
	$str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( $str );
}

sub http_referer {
	my $str = $ENV{'HTTP_REFERER'};
	$str =~ tr/+/ /;
	$str =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
	return( $str );
}

sub remote_addr { $ENV{'REMOTE_ADDR'} || '127.0.0.1' }
sub remote_host { $ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 
	'localhost' }
sub remote_user { $ENV{'AUTH_USER'} || $ENV{'LOGON_USER'} || 
	$ENV{'REMOTE_USER'} || $ENV{'HTTP_FROM'} || $ENV{'REMOTE_IDENT'} }
sub user_agent { $ENV{'HTTP_USER_AGENT'} }

######################################################################

sub is_mod_perl {
	return( defined( $ENV{'GATEWAY_INTERFACE'} ) &&
		$ENV{'GATEWAY_INTERFACE'} =~ /^CGI-Perl/ );
}

######################################################################

sub base_url {
	my $self = shift( @_ );
	my $port = $self->server_port();
	return( 'http://'.$self->virtual_host().
		($port != 80 ? ":$port" : '').
		$self->script_name() );
}

######################################################################

sub self_url {
	my $self = shift( @_ );
	my $query = $self->user_query_str() || 
		$self->user_offline_str();
	return( $self->base_url().($query ? "?$query" : '') );
}

######################################################################

sub self_post {
	my $self = shift( @_ );
	my $button_label = shift( @_ ) || 'click here';
	my $url = $self->self_url();
	my $post_fields = $self->parse_url_encoded_queries( 0, 
		$self->user_post_str() )->to_html_encoded_hidden_fields();
	return( <<__endquote );
<FORM METHOD="post" ACTION="$url">
$post_fields
<INPUT TYPE="submit" NAME="" VALUE="$button_label">
</FORM>
__endquote
}

######################################################################

sub self_html {
	my $self = shift( @_ );
	my $visible_text = shift( @_ ) || 'here';
	return( $self->user_post_str() ? 
		$self->self_post( $visible_text ) : 
		'<A HREF="'.$self->self_url().'">'.$visible_text.'</A>' );
}

######################################################################

sub user_cookie {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'CGI::HashOfArrays' ) {
		$self->{$KEY_USER_COOKIE} = $new_value->clone();
	}
	return( $self->{$KEY_USER_COOKIE} );
}

sub user_cookie_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_COOKIE}->to_url_encoded_string('; ','&') );
}

sub user_cookie_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_USER_COOKIE}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_USER_COOKIE}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_USER_COOKIE}->fetch_value( $key ) );
	}
}

######################################################################

sub user_input {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'CGI::HashOfArrays' ) {
		$self->{$KEY_USER_INPUT} = $new_value->clone();
	}
	return( $self->{$KEY_USER_INPUT} );
}

sub user_input_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_INPUT}->to_url_encoded_string() );
}

sub user_input_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( @_ ) {
		return( $self->{$KEY_USER_INPUT}->store( $key, @_ ) );
	} elsif( wantarray ) {
		return( @{$self->{$KEY_USER_INPUT}->fetch( $key ) || []} );
	} else {
		return( $self->{$KEY_USER_INPUT}->fetch_value( $key ) );
	}
}

sub user_input_keywords {
	my $self = shift( @_ );
	return( @{$self->{$KEY_USER_INPUT}->fetch( $UIP_KEYWORDS )} );
}

######################################################################

sub persistant_user_input_params {
	my $self = shift( @_ );
	if( ref( my $new_value = shift( @_ ) ) eq 'HASH' ) {
		$self->{$KEY_PERSIST_QUERY} = {%{$new_value}};
	}
	return( $self->{$KEY_PERSIST_QUERY} );
}

sub persistant_user_input_string {
	my $self = shift( @_ );
	return( $self->{$KEY_USER_INPUT}->clone( 
		[keys %{$self->{$KEY_PERSIST_QUERY}}] 
		)->to_url_encoded_string() );
}

sub persistant_user_input_param {
	my $self = shift( @_ );
	my $key = shift( @_ );
	if( defined( my $new_value = shift( @_ ) ) ) {
		$self->{$KEY_PERSIST_QUERY}->{$key} = $new_value;
	}	
	return( $self->{$KEY_PERSIST_QUERY}->{$key} );
}

sub persistant_url {
	my $self = shift( @_ );
	my $persist_input_str = $self->persistant_user_input_string();
	return( $self->base_url().
		($persist_input_str ? "?$persist_input_str" : '') );
}

######################################################################

sub parse_url_encoded_cookies {
	my $self = shift( @_ );
	my $parsed = CGI::HashOfArrays->new( shift( @_ ) );
	foreach my $string (@_) {
		$string =~ s/\s+/ /g;
		$parsed->from_url_encoded_string( $string, '; ', '&' );
	}
	return( $parsed );
}

sub parse_url_encoded_queries {
	my $self = shift( @_ );
	my $parsed = CGI::HashOfArrays->new( shift( @_ ) );
	foreach my $string (@_) {
		$string =~ s/\s+/ /g;
		if( $string =~ /=/ ) {
			$parsed->from_url_encoded_string( $string );
		} else {
			$parsed->from_url_encoded_string( 
				"$UIP_KEYWORDS=$string", undef, ' ' );
		}
	}
	return( $parsed );
}

######################################################################

1;
__END__

=head1 AUTHOR

Copyright (c) 1999-2000, Darren R. Duncan. All rights reserved. This module is
free software; you can redistribute it and/or modify it under the same terms as
Perl itself.  However, I do request that this copyright information remain
attached to the file.  If you modify this module and redistribute a changed
version then please attach a note listing the modifications.

I am always interested in knowing how my work helps others, so if you put this
module to use in any of your own code then please send me the URL.  Also, if you
make modifications to the module because it doesn't work the way you need, please
send me a copy so that I can roll desirable changes into the main release.

Address comments, suggestions, and bug reports to B<perl@DarrenDuncan.net>.

=head1 SEE ALSO

perl(1).

=cut


