#!/usr/bin/perl
package Date::Handler::Range;

use strict;
use Carp;
use Data::Dumper;

use Date::Handler;
use Date::Handler::Delta;

use vars qw($VERSION);
$VERSION = '0.01';

sub new
{
	my ($classname, $args) = @_;

	croak "No arguments to new()" if not defined $args;
	croak "No date argument passed to new()" if not defined $args->{date};

	my $self = {};
	bless $self, $classname;

	if(ref($args) eq 'HASH')
	{
		#Get the date from the arguments.
		if(UNIVERSAL::isa($args->{date}, 'Date::Handler'))
		{
			$self->{date} = $args->{date};
		}
		else
		{
			my $date = new Date::Handler({ date => $args->{date} });
			if(defined $date)
			{
				$self->{date} = $date;
			}
			else
			{
				croak "Invalid format for date in new()";
			}
		}
	
		if(UNIVERSAL::isa($args->{delta}, 'Date::Handler::Delta'))
		{
			$self->{delta} = $args->{delta};
		}
		else
		{
			my $delta = Date::Handler::Delta->new($args->{delta});
			if(defined $delta)
			{
				$self->{delta} = $delta;
			}
			else
			{
				croak "Invalid format for delta in new()";
			}
		}
	}
	else
	{
		croak "Invalid arguments passed to new() (not HASHREF)";
	}

	return $self;
}


sub Direction
{
	my $self = shift;
	my $direction = shift;

	if(defined $direction)
	{
		if($direction == 1 || $direction =~ /FORWARDS/i)
		{
			$self->{direction} = 1;
		}
		elsif($direction == 0 || $direction =~ /BACKWARDS/i)
		{
			$self->{direction} = 0;
		}
	}

	$self->{direction} = 1 if not defined $self->{direction};
	return $self->{direction};
}
			

sub Delta
{
	my $self = shift;
	my $delta = shift;

	if(defined $delta && $delta->isa('Date::Handler::Delta'))
	{
		$self->{delta} = $delta;
	}
	return $self->{delta};
}

sub Date
{
	my $self = shift;
	my $date = shift;

	if(defined $date && $date->isa('Date::Handler'))
	{
		$self->{date} = $date;
	}
	return $self->{date};
}

sub StartDate
{
	my $self = shift;

	if($self->Direction())
	{
		return $self->Date();
	}
	else
	{	
		return $self->Date() - $self->Delta();
	}
}

sub EndDate
{
	my $self = shift;
	
	if($self->Direction())
	{
		return $self->Date() + $self->Delta();
	}
	else
	{
		return $self->Date();
	}
}

sub Overlaps
{
	my $self = shift;
	my $range = shift;

	croak "Arguments to Overlaps() is not a Date::Handler::Range" if !$range->isa('Date::Handler::Range');

	return 0 if($self->EndDate() <= $range->StartDate());
	return 0 if($range->EndDate() <= $self->StartDate());
	return 1;

}

	

666;
__END__
