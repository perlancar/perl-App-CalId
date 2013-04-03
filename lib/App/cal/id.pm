package App::cal::id;

use 5.010001;
use strict;
use warnings;

use Calendar::Indonesia::Holiday qw(list_id_holidays);
use DateTime;
use List::Util qw(max);
use Term::ANSIColor;
use Text::ANSI::Util qw(ta_length);

# VERSION

my $month_names = [qw(Januari Februari Maret April Mei Juni Juli Agustus September Oktober November Desember)];
my $short_month_names = [qw(Jan Feb Mar Apr Mei Jun Jul Agt Sep Okt Nov Des)];

our %SPEC;

sub _center {
    my ($w, $text) = @_;
    my $tw = length($text);
    sprintf("%s%s%s",
            (" " x int(($w-$tw)/2)),
            $text,
            (" " x int(($w-$tw)/2)),
        );
}

sub _rpad {
    my ($w, $text) = @_;
    sprintf("%s%s", $text, " " x ($w-ta_length($text)));
}

$SPEC{gen_monthly_calendar} = {
    v => 1.1,
    args => {
        month => {
            schema => ['int*' => between => [1, 12]],
            req => 1,
        },
        year => {
            schema => ['int*'],
            req => 1,
        },
        show_title => {
            schema => ['bool', default => 1],
        },
        show_year_in_title => {
            schema => ['bool', default => 1],
        },
        show_prev_month_days => {
            schema => ['bool', default => 1],
        },
        show_next_month_days => {
            schema => ['bool', default => 1],
        },
        show_holiday_list => {
            schema => ['bool', default => 1],
        },
        return_array => {
            summary => 'If set to true, return array of lines instead of string',
            schema => 'bool',
        },
    },
    "_perinci.sub.wrapper.validate_args" => 1,
};
sub gen_monthly_calendar {
    my %args = @_; # VALIDATE_ARGS
    my $m = $args{month};
    my $y = $args{year};

    my @lines;
    my $dt  = DateTime->new(year => $y, month => $m, day => 1);
    my $dtl = DateTime->last_day_of_month(year => $y, month => $m);
    my $dt_today = DateTime->today;
    my $hol = list_id_holidays(year=>$y, month=>$m, is_joint_leave=>0, detail=>1)->[2];

    if ($args{show_title} // 1) {
        # XXX use locale
        if ($args{show_year_in_title} // 1) {
            push @lines, _center(21, sprintf("%s %d", $month_names->[$m-1], $y));
        } else {
            push @lines, _center(21, sprintf("%s", $month_names->[$m-1]));
        }
    }
    push @lines, "Sn Sl Rb Km Ju Sb Mi"; # XXX use locale (but TBH locale's versions suck: Se Se Ra Ka Ju Sa Mi)

    my $dow = $dt->day_of_week;
    $dt->subtract(days => $dow-1);
    for my $i (1..$dow-1) {
        push @lines, "" if $i == 1;
        if ($args{show_prev_month_days} // 1) {
            $lines[-1] .= colored(sprintf("%2d ", $dt->day), "bright_black");
        } else {
            $lines[-1] .= "   ";
        }
        $dt->add(days => 1);
    }
    for (1..$dtl->day) {
        if ($dt->day_of_week == 1) {
            push @lines, "";
        }
        my $col = "white";
        if (DateTime->compare($dt, $dt_today) == 0) {
            $col = "reverse";
        } else {
            for (@$hol) {
                if ($dt->day == $_->{day}) {
                    $col = "bright_red";
                }
            }
        }
        $lines[-1] .= colored(sprintf("%2d ", $dt->day), $col);
        $dt->add(days => 1);
    }
    if ($args{show_next_month_days} // 1) {
        $dow = $dt->day_of_week - 1; $dow = 7 if $dow == 0;
        for my $i ($dow+1..7) {
            $lines[-1] .= colored(sprintf("%2d ", $dt->day), "bright_black");
            $dt->add(days => 1);
        }
    }

    if ($args{show_holiday_list} // 1) {
        for my $i (0..@$hol-1) {
            push @lines, "" if $i == 0;
            push @lines, sprintf("%2d = %s", $hol->[$i]{day}, $hol->[$i]{ind_name});
        }
    }

    if ($args{return_array}) {
        return \@lines;
    } else {
        return join "\n", @lines;
    }
}

$SPEC{gen_yearly_calendar} = {
    v => 1.1,
    args => {
        year => {
            schema => ['int*'],
            req => 1,
        },
        show_title => {
            schema => ['bool', default => 1],
        },
        show_holiday_list => {
            schema => ['bool', default => 1],
        },
        return_array => {
            summary => 'If set to true, return array of lines instead of string',
            schema => 'bool',
        },
    },
    "_perinci.sub.wrapper.validate_args" => 1,
};
sub gen_yearly_calendar {
    my %args = @_; # VALIDATE_ARGS
    my $y = $args{year};

    my @lines;
    my $hol = list_id_holidays(year=>$y, is_joint_leave=>0, detail=>1)->[2];

    if ($args{show_title} // 1) {
        push @lines, _center(67, $y);
    }

    my @moncals; # index starts from 1
    for my $m (1..12) {
        $moncals[$m] = gen_monthly_calendar(
            month=>$m, year=>$y,
            show_year_in_title   => 0,
            show_holiday_list    => 0,
            show_prev_month_days => 0,
            show_next_month_days => 0,
            return_array => 1,
        );
    }
    my $l = max(map {~~@$_} @moncals[1..12]);
    for my $i (0..3) {
        for (0..$l-1) {
            push @lines,
                sprintf("%s %s %s",
                        _rpad(21, $moncals[$i*3+1][$_]//""),
                        _rpad(21, $moncals[$i*3+2][$_]//""),
                        _rpad(21, $moncals[$i*3+3][$_]//""));
        }
        push @lines, "" unless $i == 3;
    }

    if ($args{show_holiday_list} // 1) {
        for my $i (0..@$hol-1) {
            push @lines, "" if $i == 0;
            push @lines, sprintf("%2d %s = %s", $hol->[$i]{day}, $short_month_names->[$hol->[$i]{month}-1], $hol->[$i]{ind_name});
        }
    }

    if ($args{return_array}) {
        return \@lines;
    } else {
        return join "\n", @lines;
    }
}

1;
#ABSTRACT: Display Indonesian calendar on the command-line

=head1 SYNOPSIS

 # See cal-id script provided in this distribution


=head1 DESCRIPTION

This module provides the B<cal-id> command to display Indonesian calendar on the
command-line.


=head1 FUNCTIONS

=head2 gen_monthly_calendar

=head2 gen_yearly_calendar

=cut
