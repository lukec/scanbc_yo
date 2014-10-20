#!/usr/bin/env perl
use strict;
use warnings;
use YAML qw/LoadFile DumpFile/;
use Net::Twitter;
use autodie;
use Try::Tiny;
use DateTime;

$| = 1; # autoflush stdout

my $Config_file = 'etc/config.yaml';
unless (-e $Config_file) {
    print "Couldn't find a config file at $Config_file!\n";
    print "Perhaps you should be mounting the config from "
        . "outside docker, using -v /foo/bar:/opt/scanbc_yo/etc\n";
    exit -1;
}
my $config = LoadFile($Config_file);

sub twitter {
    # Always re-create our twitter connection, as our requests may be far
    # apart in time, and the connection may timeout.
    return Net::Twitter->new(
        traits   => [qw/API::RESTv1_1/],
        ssl => 1,
        consumer_key    => $config->{twitter_consumer_key},
        consumer_secret => $config->{twitter_consumer_secret},
        access_token           => $config->{twitter_access_token},
        access_token_secret    => $config->{twitter_access_secret},
    );
}

sub send_tweet { twitter->update(shift) }

sub get_latest_tweets {
    my $screen_name = $config->{screen_name};
    my $tweets = twitter->user_timeline({
            screen_name => $screen_name,
            count => 200,
        });
    return [ sort { "$a->{id}" cmp "$b->{id}" } @$tweets ];
}

sub now { DateTime->now->set_time_zone('America/Vancouver') }

sub is_good_time_to_tweet {
    my $now = now();
    if ($now->day_of_week > 5) { # weekend
        return 1 if $now->hour < 1;
        return 1 if $now->hour > 9;
    }
    else { # on weekdays, only tweet from 9pm to 1 am
        return 1 if $now->hour < 1;
        return 1 if $now->hour > 21;
    }
    return 0;
}

# Every X minutes check for new tweets
while (1) {
    print "Checking for latest tweets ...\n";
    my $recent_tweets = get_latest_tweets();

    for my $t (@$recent_tweets) {
        while (not is_good_time_to_tweet()) {
            my $now = now();
            print "Hour is @{[$now->hour]} - It's not a good time to tweet. Sleeping for 15 minutes.\n";
            sleep 60*15;
        }

        if ($config->{seen}{$t->{id}}) {
            print "SKIPPING old tweet $t->{id} - $t->{text}\n";
            next;
        }

        my $new_tweet = goldfishify($t->{text}) or next;
        if (length($new_tweet) > 140) {
            print "SKIPPING too big: $t->{id} - $t->{text}\n";
            next;
        }

        # Remove all hashes, so we don't show up in hashtag searches
        $new_tweet =~ s/#//g;
        $new_tweet =~ s/&amp;/&/;

        # We have found a new tweet to send out!
        print "$t->{id} - Found next tweet to send out: $new_tweet\n";

        try { send_tweet($new_tweet) }
        catch {
            warn "Failed to send tweet: '$new_tweet': $_";
        };

        # Record that we've sent it, regardless of if it was successful.
        $config->{seen}{$t->{id}} = 1;
        save_config($config);

        # Send it out and then wait ~0-3 hours
        my $wait_for = int(rand(180)+10);
        my $now = now();
        print $now->hms . " - Sleeping for $wait_for minutes!\n";
        sleep $wait_for * 60;
    }

    print "Ran out of tweets to send! Sleeping for 5 minutes.\n";
    sleep 5 * 60;
}



exit;

sub goldfishify {
    my $text = shift;

    $text =~ s/\s+(pic|photo by) \@.+//i;
    return $text if $text =~ s/one mail (.+?) another/\@Goldfishyo $1 someone/ig;
    return $text if $text =~ s/water main/\@Goldfishyo/ig;
    return $text if $text =~ s/(one|two|three|four|five) Suspects? /\@Goldfishyo /ig;

    return $text if $text =~ s/hit by a \w+/hit by \@Goldfishyo/ig;
    return $text if $text =~ s/(the )?Suspects?\b/\@Goldfishyo/ig;
    return $text if $text =~ s/Subject\b/\@Goldfishyo/ig;
    return $text if $text =~ s/(multiple|a|one|two|three|four|five|\d+) (person|people|(fe)?male|adults)s?\b/\@Goldfishyo/ig;
    return $text if $text =~ s/rescue a \S+ /rescue \@Goldfishyo /ig;
    return $text if $text =~ s/a cyclist /\@Goldfishyo /ig;
    return $text if $text =~ s/\b(fe)?males?\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\b(person|someone|hiker)\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\bby a \d+ y\/o/by \@Goldfishyo/ig;
    return $text if $text =~ s/requested from (\S+)/requested from \@Goldfishyo/ig;
    return $text if $text =~ s/\boccupants?\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\bseveral people\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\ba \d+ year old\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\b\d+ patients\b/\@Goldfishyo/ig;
    return $text if $text =~ s/\bSearch &amp; Rescue/\@Goldfishyo/ig;
    return $text if $text =~ s/#\w+ (fire )?(crews|police) are/\@Goldfishyo is/ig;
    return undef;
}

sub save_config {
    my $bak = "$Config_file.bak";
    unlink $bak if -e $bak;
    DumpFile($bak, $config);
    rename $bak => $Config_file;
}
