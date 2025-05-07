#!/usr/bin/env perl
#
# Don't try to follow the logic in here, XML::Twig allows for some real nonsense

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);
use XML::Twig;

my $inSettings = 0;
my @list = ();
my @clipboard = ();
my $help = 0;
my $after;
my $move;
my $to;

GetOptions(
    'help|?'      => \$help,
    'add-after=s' => \$after,
    'move=s'      => \$move,
    'to=s'        => \$to,
) or pod2usage(2);
pod2usage(1) if $help || ($move && !$to) || (!$move && $to);

my $xml = shift || pod2usage(2);

my $twig = XML::Twig->new(
    twig_handlers => {
        '#COMMENT' => sub {
            my ($t, $comment) = @_;
            if ($comment->{comment} eq 'Settings View Controller') {
                $inSettings = 1;
            }
            else {
                $inSettings = 0;
            }
        },
        label => sub {
            my ($t, $label) = @_;
            if ($inSettings) {
                push @list, [ label => $label ];
            }
        },
        segmentedControl => sub {
            my ($t, $control) = @_;
            if ($inSettings) {
                push @list, [ control => $control ];
            }
        },
        slider => sub {
            my ($t, $slider) = @_;
            if ($inSettings) {
                push @list, [ slider => $slider ];
            }
        },
        view => sub {
            my ($t, $view) = @_;
            if ($inSettings) {
                push @list, [ view => $view ];
            }
        },
    },
    comments        => 'process',
    keep_atts_order => 1,
    pretty_print    => 'indented',
    empty_tags      => 'normal',
);

$twig->parsefile($xml);

if ($after) {
    do_after($twig, $after);
}
elsif ($move && $to) {
    do_move($twig, $move, $to);
}

do_output($twig);

sub do_after {
    my ($twig, $after) = @_;

    my $LABEL_TEMPLATE = qq{
    <label opaque="NO" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" fixedFrame="YES" text="New Label Template" textAlignment="natural" lineBreakMode="tailTruncation" baselineAdjustment="alignBaselines" adjustsFontSizeToFit="NO" translatesAutoresizingMaskIntoConstraints="NO" id="%s">
        <rect key="frame" x="16" y="999" width="35" height="21"></rect>
        <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMaxY="YES"></autoresizingMask>
        <fontDescription key="fontDescription" type="system" pointSize="17"></fontDescription>
        <color key="textColor" red="0.93902439019999995" green="0.9625305918" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"></color>
        <nil key="highlightedColor"></nil>
    </label>};

    my $CONTROL_TEMPLATE = qq{
    <segmentedControl opaque="NO" contentMode="scaleToFill" fixedFrame="YES" contentHorizontalAlignment="left" contentVerticalAlignment="top" segmentControlStyle="plain" selectedSegmentIndex="0" translatesAutoresizingMaskIntoConstraints="NO" id="%s" userLabel="New Control Template">
        <rect key="frame" x="16" y="999" width="459" height="28"></rect>
        <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMaxY="YES"></autoresizingMask>
        <segments>
            <segment title="No"></segment>
            <segment title="Yes"></segment>
        </segments>
        <color key="tintColor" red="0.6716768742" green="0.61711704730000005" blue="0.99902987480000005" alpha="1" colorSpace="custom" customColorSpace="sRGB"></color>
        <color key="selectedSegmentTintColor" red="0.6716768742" green="0.61711704730000005" blue="0.99902987480000005" alpha="1" colorSpace="custom" customColorSpace="sRGB"></color>
    </segmentedControl>};

    my @to_add = (
        [ label   => XML::Twig::Elt->parse( sprintf($LABEL_TEMPLATE, generate_id()) ) ],
        [ control => XML::Twig::Elt->parse( sprintf($CONTROL_TEMPLATE, generate_id()) ) ],
    );

    # Find where to insert them
    for (my $i = 0; $i < scalar @list; $i++) {
        my ($type, $e) = @{$list[$i]};
        if ($type eq 'label' && ($e->att('text') // q{}) eq $after) {
            ($type, $e) = @{$list[$i + 1]};

            # paste the block to a new location
            for my $tm (@to_add) {
                $tm->[1]->paste(after => $e);
                $e = $tm->[1];
            }

            # also move the block in the ordering list, which is where the y values are adjusted
            $i += 2;
            splice(@list, $i, 0, @to_add);
        }
    }
}

sub do_move {
    my ($twig, $move, $to) = @_;

    my @to_move = ();

    # Pull out the bits to move
    for (my $i = 0; $i < scalar @list; $i++) {
        my ($type, $e) = @{$list[$i]};
        if ($type eq 'label' && ($e->att('text') // q{}) eq $move) {
            # move this item and the next one (the control)
            push @to_move, [ $type => $e->cut ];
            ($type, $e) = @{$list[$i + 1]};
            push @to_move, [ $type => $e->cut ];
            splice(@list, $i, 2);
            last;
        }
    }

    # Find where to insert them
    for (my $i = 0; $i < scalar @list; $i++) {
        my ($type, $e) = @{$list[$i]};
        if ($type eq 'label' && ($e->att('text') // q{}) eq $to) {
            ($type, $e) = @{$list[$i + 1]};

            # paste the block to a new location
            for my $tm (@to_move) {
                $tm->[1]->paste(after => $e);
                $e = $tm->[1];
            }

            # also move the block in the ordering list, which is where the y values are adjusted
            $i += 2;
            splice(@list, $i, 0, @to_move);
        }
    }
}

sub do_output {
    my $twig = shift;

    # first label
    my $x = 16;
    my $y = 20;

    # spacing
    my $label_to_control = 29;
    my $control_to_label = 35;
    my $label_to_label =   43;
    my $slider_to_next   = 29;
    my $view_to_next     = 43;
    my $seen_rdv = 0;
    my $last = q{};

    printf STDERR "%30s    %s    %s\n\n", q{}, "auto", "current";

    for my $row (@list) {
        my ($type, $e) = @{$row};
        my $rect = $e->has_child('rect');
        my $orig_y = $rect->att('y');

        $rect->set_att(x => $x);
        $rect->set_att(y => $y);

        if ($type eq "label") {
            my $text = $e->att('userLabel') // $e->att('text') // "(unknown label)";
            printf STDERR "%30s    %d    %4d\n", $text, $y, $orig_y;

            if ($text =~ /Caption/) { # space after captions is a bit larger
                $y += $label_to_label;
            }
            else {
                $y += $label_to_control;
            }
        }
        elsif ($type eq "control") {
            my ($userLabel) = $e->att('userLabel') // "(unknown control)";
            printf STDERR "%30s    %d    %4d\n", $userLabel, $y, $orig_y;

            $y += $control_to_label;
        }
        elsif ($type eq "slider") {
            printf STDERR "%30s    %d    %4d\n", "slider", $y, $orig_y;
            $y += $slider_to_next;
        }
        elsif ($type eq "view") {
            my $customClass = $e->att('customClass') // q{};
            if ($customClass && $customClass eq "UIScrollView") {
                # This is the entire view, so we're done
                last;
            }

            printf STDERR "%30s    %d    %4d\n", "view", $y, $orig_y;
            $y += $view_to_next;
        }
        $last = $type;
    }

    # Output the entire XML with our changes
    $twig->print;
}

sub generate_id {
    # generate an id of the form K4A-oH-Bs0
    my $chars = [ split //, 'abcdefghiklmnopqrstuvwxyzABCDEFGHIKLMNOPQRSTUVWXYZ0123456789' ];

    my $random_fragment = sub {
        my $length = shift;
        return '' if $length < 1;
        my $fragment = '';
        $fragment .= $chars->[int(rand(scalar @{$chars}))] for (1..$length);
        return $fragment;
    };

    return join '-', (
        $random_fragment->(3),
        $random_fragment->(2),
        $random_fragment->(3),
    );
}

=pod

=head1 NAME

SettingsHelper.pl - Less painful storyboard settings elements

=head1 SYNOPSIS

SettingsHelper.pl [options] [iPad.storyboard] > New.storyboard

Run with no options to display the list of items in a storyboard.

  Options:
    --add-after LABEL            Insert a new empty label + control pair after the given label (and its control)
    --move FROM --to TO          Move the first label and control after the "to" label
    --help                       This help message.

=cut
