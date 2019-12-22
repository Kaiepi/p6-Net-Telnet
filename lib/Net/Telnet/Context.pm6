use v6.d;
use Net::Telnet::Constants :ALL;
use Net::Telnet::Exceptions;
use Net::Telnet::Option;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation;
unit class Net::Telnet::Context;

# Request represents a negotiation/subnegotiation awaiting a response from the
# peer. Requests can be used with await to get the command the peer replies
# with (this is mainly used in Storage, see below), since it does Awaitable and
# is just a more basic version of Promise. Requests are used for chaining
# sending negotiations/subnegotiations and getting their responses multiple
# times in a row sequentially in combination with Storage.
class Request does Awaitable {
    my class RequestHandle does Awaitable::Handle {
        has &!add-subscriber;

        method not-ready(&add-subscriber) {
            self.CREATE!not-ready: &add-subscriber
        }
        method !not-ready(&add-subscriber) {
            $!already         = False;
            &!add-subscriber := &add-subscriber;
            self
        }

        method subscribe-awaiter(&subscriber --> Nil) {
            &!add-subscriber(&subscriber)
        }
    }

    has Lock $!lock;
    has Bool $!resolved;
    has      $!result;
    has      &!on-resolve;

    submethod BUILD() {
        $!lock     := Lock.new;
        $!resolved := False;
    }

    method resolve($negotiation --> Nil) {
        $!lock.protect({
            $!resolved := True;
            $!result   := $negotiation;
            $*SCHEDULER.cue(&!on-resolve) if &!on-resolve.defined;
        })
    }

    method get-await-handle(--> Awaitable::Handle:D) {
        if $!resolved {
            RequestHandle.already-success: $!result;
        } else {
            RequestHandle.not-ready(-> &on-ready {
                $!lock.lock;
                if $!resolved {
                    $!lock.unlock;
                    on-ready True, $!result;
                } else {
                    &!on-resolve := { on-ready True, $!result };
                    $!lock.unlock;
                }
            })
        }
    }
}

# Storage is a Hash of TelnetOption to Request. It features helper methods for
# creating new requests, resolving requests, and awaiting their response given
# a negotiation/subnegotiation's command and option.
my class Storage {
    my role TypedStorage[::TValue] is Hash[Request, TelnetOption] {
        # Checks if a request exists or not.
        method has(TelnetOption $option --> Bool) {
            self.EXISTS-KEY: $option
        }

        # Gets a request.
        method get(TelnetOption $option --> Request) {
            self!throw: $option unless self.EXISTS-KEY: $option;
            self.AT-KEY: $option
        }

        # Initializes a negotiation request, if none has been yet.
        method request(TelnetOption $option --> Request) {
            if self.EXISTS-KEY: $option {
                self.AT-KEY: $option
            } else {
                self.BIND-KEY: $option, Request.new
            }
        }

        # Resolves a negotiation request with the received
        # negotiation/subnegotiation as the request's value.
        method resolve(TValue $negotiation --> Request) {
            my TelnetOption $option  = $negotiation.option;
            # We sometimes initialize requests here since they're not
            # guaranteed to have been initialized (like when the client
            # receives a negotiation from the server when first connecting).
            my Request      $request = self.request: $option;
            $request.resolve: $negotiation;
            $request
        }

        # Removes a request. Call this after awaiting the response of a
        # request.
        method remove(TelnetOption $option --> Request) {
            self!throw: $option unless self.EXISTS-KEY: $option;
            self.DELETE-KEY: $option;
        }

        method !throw(TelnetOption $option) {
            my Str $type   = TValue.^shortname.lc;
            my Str $action = callframe(1).code.name;
            X::Net::Telnet::OptionRace.new(:$option, :$type, :$action).throw;
        }
    }

    method ^parameterize(Storage:U $this is raw, Mu $type is raw) {
        my Storage:U $mixin := $this.^mixin: TypedStorage.^parameterize: $type;
        $mixin.^set_name: $this.^name ~ '[' ~ $type.^name ~ ']';
        say $mixin;
        $mixin
    }
}

my constant Negotiation    = Net::Telnet::Negotiation;
my constant Subnegotiation = Net::Telnet::Subnegotiation;

# XXX: should use `has TelnetOption:D @ is Set` etc. once that works (again?).
has Set:D[TelnetOption:D]     $.preferred               is required;
has Set:D[TelnetOption:D]     $.supported               is required;
has Net::Telnet::Option:D     %.options{TelnetOption:D} is required;
has Storage[Negotiation:D]    $.negotiations            is required;
has Storage[Subnegotiation:D] $.subnegotiations         is required;

submethod BUILD(::?CLASS:D: :@preferred!, :@supported!) {
    $!preferred       .= new: @preferred;
    $!supported       .= new: @supported;
    %!options          = TelnetOption.^enum_value_list.map(-> TelnetOption:D $option {
        my Bool:D $supported = $!supported ∋ $option;
        my Bool:D $preferred = $!preferred ∋ $option;
        $option => Net::Telnet::Option.new: :$option, :$supported, :$preferred
    });
    $!negotiations    .= new;
    $!subnegotiations .= new;
}

method new(::?CLASS:_: :@preferred, :@supported --> ::?CLASS:D) {
    self.bless: :@preferred, :@supported
}
