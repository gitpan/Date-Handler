#!/usr/bin/perl
package Date::Handler::Delta;

use strict;
use Carp;
use Data::Dumper;
use vars qw(@ISA $VERSION);

$VERSION = '0,01';

use POSIX qw(floor strftime mktime);

use overload (
	'""'	=> 'AsScalar',
	'0+'	=> 'AsNumber',
	'neg'	=>	'Neg',
	'+'	=>	'Add',
	'-'	=>	'Sub',
	'*' =>  'Mul',
	'/' =>  'Div',
	'<=>'	=>	'Cmp',
	'++' => 'Incr',
	'%' => sub { croak "Impossible to modulo a Date::Handler::Delta"; },
	'**' => sub { croak "Trying to obtain square virtual minutes out of a virtual delta boy ?"; }, 
	fallback	=> 1,
);


sub new
{
	my ($classname, $delta) = @_;

	my $self = {};
	bless $self, $classname;

	croak "No args to new()" if not defined $delta;

	if(ref($delta) =~ /ARRAY/)
	{
		my $delta_array = $self->DeltaFromArray($delta);
		$self->{months} = $delta_array->[0];
		$self->{seconds} = $delta_array->[1];
	}
	elsif(ref($delta) =~ /HASH/)
	{
		my $delta_array = $self->DeltaFromArray([
							$delta->{years},
							$delta->{months},
							$delta->{days},
							$delta->{hours},
							$delta->{minutes},
							$delta->{seconds},
							]);
		$self->{months} = $delta_array->[0];
		$self->{seconds} = $delta_array->[1];
							 
	}
	elsif(!ref($delta))
	{
		$self->{seconds} = $delta;
	}
	else
	{
		croak "Arguments to new in unknown format.";
	}
	
	croak "Could not parse delta" if !defined $self->{months} && !defined $self->{seconds};

	return $self;
}	



#Accessors (Might want to optimised some of those)
sub Months { return shift->{months}; }
sub Seconds  { return shift->{seconds}; }


#Oveload methods.
sub AsScalar { return sprintf("%d:%d", @{shift()->AsArray()}); }
sub AsNumber { return sprintf("%d.%d",@{shift()->AsArray()}); }

sub AsArray
{
	my $self = shift;
	return [$self->Months()||0,$self->Seconds()||0];
}

sub AsHash
{
	my $self = shift;

	return {
				month => $self->Months(),
				day => $self->Seconds(),
		};
}


sub Add 
{
	my ($self, $delta) = @_;

	my $self_array = $self->AsArray();

	if(!ref($delta))
	{
		$self_array->[1] += $delta;
	}
	elsif($delta->isa('Date::Handler::Delta'))
	{
		$self_array->[0] += $delta->Months();
		$self_array->[1] += $delta->Seconds();
	}
	elsif($delta->isa('Date::Handler'))
	{
		return $delta->Add($self);
	}
	else
	{
		$self_array->[1] += $delta;
	}

	return new Date::Handler::Delta([0, $self_array->[0], 0,0,0,$self_array->[1]]);
}

sub Sub 
{
	my ($self, $delta) = @_;

	if(ref($delta) && $delta->isa('Date::Handler'))
	{
		croak "Cannot substract a date from a Delta.";
	}

	return $self->Add(-$delta);
}
sub Cmp 
{
	my ($self, $delta) = @_;

	croak "Cannot compare a Delta with something else than another Delta" if(!ref($delta));

	if($delta->isa('Date::Handler::Delta'))
	{
		my $self_time = 24*60*60*(30*$self->Months())+$self->Seconds();
		my $delta_time = 24*60*60*(30*$delta->Months())+$delta->Seconds();

		return $self_time <=> $delta_time;
	}
	else
	{
		croak "Cannot compare a Delta with something else than another Delta";
	}
	
}

sub Mul 
{
	my ($self, $delta) = @_;

	if(!ref($delta)) 
	{
		my $months = $self->Months() * $delta;
		my $seconds = $self->Seconds() * $delta;

		return new Date::Handler::Delta([0, $months,0,0,0,$seconds]);
	}
	elsif($delta->isa('Date::Handler::Delta'))
	{
		croak "Cannot obtain square minutes from Delta multiplication";
	}
	elsif($delta->isa('Date::Handler'))
	{
		croak "Cannot Multiply a date with a delta.";
	}
	else
	{
		my $months = $self->Months() * $delta;
		my $seconds = $self->Seconds() * $delta;

		return new Date::Handler::Delta([0, $months,0,0,0,$seconds]);
	}

}
sub Div 
{
	my ($self, $delta) = @_;

	if(!ref($delta))
	{
		my $months = floor($self->Months() / $delta);
		my $seconds = floor($self->Seconds() / $delta);

		return new Date::Handler::Delta([0, $months,0,0,0,$seconds]);
	}
	elsif($delta->isa('Date::Handler::Delta'))
	{
		croak "Cannot divide 2 deltas.";
	}
	elsif($delta->isa('Date::Handler'))
	{
		croak "Cannot divide a date and a delta.";
	}
	else
	{
		my $months = floor($self->Months() / $delta);
		my $seconds = floor($self->Seconds() / $delta);

		return new Date::Handler::Delta([0, $months,0,0,0,$seconds]);
	}
}

sub Incr
{
	my $self = shift;

	my $secs = $self->Seconds();

	return new Date::Handler::Delta([0, $self->Months(),0,0,0,$secs++]);
}

sub Neg
{
	my $self = shift;

	return new Date::Handler::Delta([0, -$self->Months(),0,0,0,-$self->Seconds()]);
}


#Useful methods.

#Taken from Class::Date
sub DeltaFromArray 
{
	my $self = shift;
	my $input = shift;
  	my ($y,$m,$d,$hh,$mm,$ss) = @{$input}[0,1,2,3,4,5];

	$y = floor($y * 12);
	$m += $y;
	return [$m||0,($ss||0)+60*(($mm||0)+60*(($hh||0)+24*($d||0)))];
}


666;
