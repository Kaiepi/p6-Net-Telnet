use v6.d;
use Net::Telnet::Constants;
use Net::Telnet::Exceptions;
use Net::Telnet::Negotiation;
use Net::Telnet::Subnegotiation;
unit class Net::Telnet::Pending;

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

    has Lock                    $!lock;
    has Lock::ConditionVariable $!cond;
    has Bool                    $!resolved;
    has                         $!result;
    has                         &!on-resolve;

    submethod BUILD() {
        $!lock     := Lock.new;
        $!cond     := $!lock.condition;
        $!resolved := False;
    }

    method resolve($negotiation --> Nil) {
        $!lock.protect({
            $!resolved := True;
            $!result   := $negotiation;
            $*SCHEDULER.cue(&!on-resolve) if &!on-resolve.defined;
            $!cond.signal_all;
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
class Storage {
    my role TypedStorage[::TValue] is Hash[Request, TelnetOption] {
        method request(TelnetOption $option --> Request) {
            if self.EXISTS-KEY: $option {
                self.AT-KEY: $option
            } else {
                self.BIND-KEY: $option, Request.new
            }
        }

        method resolve(TValue $negotiation --> Request) {
            my TelnetOption $option = $negotiation.option;
            self.request: $option unless self.EXISTS-KEY: $option;

            my Request $request = self.AT-KEY: $option;
            $request.resolve: $negotiation;
            $request
        }

        method remove(TelnetOption $option --> Request) {
            return self!throw: $option unless self.EXISTS-KEY: $option;

            my Request $request = self.AT-KEY: $option;
            self.DELETE-KEY: $option;
            $request
        }

        method !throw(TelnetOption $option) {
            my Str $type   = TValue.^shortname.lc;
            my Str $action = callframe(1).code.name;
            X::Net::Telnet::OptionRace.new(:$option, :$type, :$action).throw;
        }
    }

    method ^parameterize(Mu:U \this, Mu \T) {
        my $type := this.^mixin: TypedStorage[T];
        $type.^set_name: this.^name ~ '[' ~ T.^name ~ ']';
        $type
    }
}

has Storage[Net::Telnet::Negotiation]    $.negotiations    .= new;
has Storage[Net::Telnet::Subnegotiation] $.subnegotiations .= new;