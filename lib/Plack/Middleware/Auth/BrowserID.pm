package Plack::Middleware::Auth::BrowserID;

use 5.012;
use warnings;
use Carp 'croak';

use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw( audience );
use Plack::Response;
use Plack::Session;

use LWP::Protocol::https;
use LWP::UserAgent;
use Mozilla::CA;
use JSON;


sub prepare_app {
    my $self = shift;

    $self->audience or croak 'audience is not set';
}

sub call {
    my ( $self, $env ) = @_;

    my $req     = Plack::Request->new($env);
    my $session = Plack::Session->new($env);

    if ( $req->method eq 'POST' ) {
        my $uri  = 'https://verifier.login.persona.org/verify';
        my $json = {
            assertion => $req->body_parameters->{'assertion'},
            audience  => $self->audience
        };
        my $persona_req = HTTP::Request->new( 'POST', $uri );
        $persona_req->header( 'Content-Type' => 'application/json' );
        $persona_req->content( to_json( $json, { utf8 => 1 } ) );

        my $ua = LWP::UserAgent->new(
            ssl_opts    => { verify_hostname => 1 },
            SSL_ca_file => Mozilla::CA::SSL_ca_file()
        );

        my $res      = $ua->request($persona_req);
        my $res_data = from_json( $res->decoded_content );

        if ( $res_data->{'status'} eq 'okay' ) {
            $session->set( 'email', $res_data->{'email'} );
            return [
                200, [ 'Content-type' => 'text' ],
                [ 'welcome! ' . $res_data->{'email'} ]
            ];
        }
        else {
            return [
                500, [ 'Content-type' => 'text' ],
                ['nok']
            ];
        }

    }

    # Logout
    $session->remove('email');

    my $res = Plack::Response->new;
    $res->cookies->{email} = { value => undef, path => '/' };
    $res->redirect('/');
    return $res->finalize;
}

1;

#ABSTRACT: Plack Middleware to integrate with Mozilla Persona (Auth by email)

=pod

=head1 SYNOPSIS

    use Plack::Builder;

    builder {
        enable 'Session', store => 'File';

        mount '/auth' => builder {
            enable 'Auth::BrowserID', audience => 'http://localhost:8082/';
        };

        mount '/'      => $app;
    }

=head1 DESCRIPTION

Mozilla Persona is a secure solutions, to identify (login) users based on email address.

"Simple, privacy-sensitive single sign-in: let your users sign into your website with their email address, and free yourself from password management."

Some code is needed in the client side, please see the example on tests and read the Mozilla Persona info on MDN.

See the functional example on the example folder.

  plackup -s Starman -r -p 8082 -E development -I lib example/app.psgi


=head1 SEE ALSO

L<Plack::Middleware::Session>
L<LWP::Protocol::https>
L<Net::BrowserID::Verify>

=cut

__END__
