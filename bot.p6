
use API::Discord;

sub MAIN(:$token!, :$channel-id!, :$input!, :$trigger!) {
  my $infinite-garbage = infinite-garbage($input.IO);
  my $api = API::Discord.new(:$token);

  await $api.connect;

  multi send-garbage(API::Discord::Channel $channel, Str() $garbage) {
    $channel.trigger-typing.then: {
      Promise.in((2..5).pick).then: {
        $channel.send-message($garbage);
      }
    }
  }

  multi send-garbage(Str $channel-id, Str() $garbage) {
    $api.get-channel($channel-id).then: -> $p {
      send-garbage($p.result, $garbage);
    }
  }

  react {
    whenever $api.messages -> $message {
      if $message.content ~~ m:i/$trigger/ {
        await send-garbage($message.channel.result, $infinite-garbage(3));
      }
    }

    whenever Supply.interval(60) {
      await $api.get-channel($channel-id).then: -> $p {
        my $channel = $p.result;

        given (^60).pick {
          send-garbage($channel, $infinite-garbage(5)) when 0;
          $channel.trigger-typing when * < 30;
        }
      }
    }
  }
}

sub infinite-garbage(IO::Path $input) {
  my \L = 3;

  sub is-eos($_) {
    m:i/<!after ['z.' \s? 'b' || \d+ || 'min' 'd'? || 'bzw']> <[.!?]>+ ')'? $/
  }

  my @s = gather {
    for $input.lines {
      my @s;

      for .words {
        my $in-quote = /^<:Quotation_Mark>/ ff /<:Quotation_Mark> <:P>* $/;

        @s.push: $_;
        @s.clone.take, @s = [] if !$in-quote && .&is-eos;
      }

      take @s.clone if +@s;
    }
  };

  my @f = @s.map(*.head(L).Str);
  my %w = (@s.map(|*)).rotor(L.succ => -L).classify(~*[^L], :as(*.tail));

  %w{*}.=map(*.Bag);

  say 'Garbage preparation took ', (now - ENTER now), ' seconds.';

  -> $n {
    gather {
      (my @k = @f.pick.words)>>.take;

      loop {
        @k = |@k.tail(L - 1), %w{~@k}.pick || last;
        @k.tail.take;
        last if @k.tail.&is-eos;
      }
    } xx (1..$n).pick
  }
}
