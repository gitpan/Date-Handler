#!/usr/bin/perl
package Date::Handler;

use strict;
use Carp;
use Data::Dumper;
use vars qw(@ISA $VERSION);

$VERSION = '0.07';

use POSIX qw(floor strftime mktime);

use Date::Handler::Constants;
use constant DEFAULT_FORMAT_STRING => "%A, %B %e %Y %R:%S (%Z)";
use constant DEFAULT_TIMEZONE => 'GMT';
use constant DELTA_CLASS => 'Date::Handler::Delta';

use overload (
	'""'	=> 'AsScalar',
	'0+'	=> 'AsNumber',
	'+'	=>	'Add',
	'-'	=>	'Sub',
	'<=>'	=>	'Cmp',
	'++' => 'Incr',
	'*' => sub { croak "Cannot multiply an absolute date"; },
	'**' => sub { croak "Cannot power an absolute date"; },
	'/' => sub { croak "Cannot divide an absolute date"; },
	fallback	=> 1,
);


sub new
{
	my ($classname, $args) = @_;

	my $self = {};
	bless $self, $classname;

	croak "No args to new()" if not defined $args;
	croak "Argument to new() is not a hashref" if not ref($args) =~ /HASH/;
	croak "No date specified for new()" if not defined $args->{date};

	my $date = $args->{date};
	$self->{time_zone} = $args->{time_zone} || $self->DEFAULT_TIMEZONE();

	if(ref($date) =~ /SCALAR/)
	{
		$self->{epoch} = $date;
	}
	elsif(ref($date) =~ /ARRAY/)
	{
		$self->{epoch} = $self->Array2Epoch($date);
	}
	elsif(ref($date) =~ /HASH/)
	{
		$self->{epoch} = $self->Array2Epoch([
												$date->{year},
												$date->{month},
												$date->{day},
												$date->{hour},
												$date->{min},
												$date->{sec},
											]);
	}
	else
	{
		$self->{epoch} = $date;
	}

	croak "Date format not recognized." if not defined $self->{epoch};

	return $self;
}	


#Accessors (Might want to optimised some of those)
sub Year { return shift->AsArray()->[0]; }
sub Day { return shift->AsArray()->[2]; }
sub Hour { return shift->AsArray()->[3]; }
sub Min { return shift->AsArray()->[4]; }
sub Sec { return shift->AsArray()->[5]; }


#To be consistent with our WeekDay function, wich is zero based.
sub Month
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return strftime('%m', localtime($self->{epoch}));
}

sub Epoch
{
	my $self = shift;

	if(@_)
	{
		my $epoch = shift;

		$self->{epoch} = $epoch;
	}

	return $self->{epoch};
}

sub TimeZone
{
	my $self = shift;
	
	if(@_)
	{
		my $time_zone = shift;

		$self->{time_zone} = $time_zone;
	}

	return $self->{time_zone};
}


#Time Conversion and info methods 

sub TimeZoneName
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	#Old code.
	#my ($std,$dst) = POSIX::tzname();
	#return $std." / ".$dst;

	return strftime("%Z", localtime($self->{epoch}) );
}

sub LocalTime
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return localtime($self->{epoch});
}


sub TimeFormat
{
	my $self = shift;
	my $format_string = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	$format_string ||= $self->DEFAULT_FORMAT_STRING(); 
	return strftime($format_string, localtime($self->{epoch}));
}


sub GmtTime
{
	my $self = shift;
	local $ENV{'TZ'} = $self->TimeZone();
	return gmtime($self->{epoch});
}

sub UtcTime
{
	my $self = shift;
	local $ENV{'TZ'} = $self->TimeZone();
	return gmtime($self->{epoch});
}


#Idea and base code for this function from:
# Larry Rosler, February 13, 1999, Thanks Larry! -<bbeausej@pobox.com>

sub GmtOffset 
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	#Old code.
	#use Time::Local;
	#my $gmt_time = timegm( gmtime $self->{epoch} );
	#my $local_time = timelocal( gmtime $self->{epoch} );


	my $now = time();
	
	my ($l_min, $l_hour, $l_year, $l_yday) = (localtime $now)[1, 2, 5, 7];
	my ($g_min, $g_hour, $g_year, $g_yday) = (gmtime $now)[1, 2, 5, 7];

	return (($l_min - $g_min)/60 + $l_hour - $g_hour + 24 * ($l_year - $g_year || $l_yday - $g_yday)) * 3600;
}


#Useful methods
sub MonthName
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return strftime('%B', localtime($self->{epoch}));
}

sub WeekDay
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return strftime('%u', localtime($self->{epoch}));
}

sub WeekDayName
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return strftime('%A', localtime($self->{epoch}));
}

sub FirstWeekDayOfMonth
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
		
	return (($self->WeekDay() - $self->Day() % 7) + 8) % 7;
}

sub WeekOfMonth
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	return int(($self->Day() + $self->FirstWeekDayOfMonth() - 1) / 7) + 1;
}
	

sub DaysInMonth
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
	my $month = $self->Month() - 1;

	if($month == 1) #Feb
	{
		return 29 if $self->IsLeapYear();
		return 28;
	}
	else
	{
		return $DAYS_IN_MONTH->{$month};
	}
}
	
sub DayLightSavings
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	my @self_localtime = localtime($self->{epoch});

	return $self_localtime[8]; 
}

sub DayOfYear
{
	my $self = shift;
	
	local $ENV{'TZ'} = $self->TimeZone();
	
	my @self_localtime = localtime($self->{epoch});

	return $self_localtime[7];
}

sub DaysInYear
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
	return 365 if !$self->IsLeapYear();
	return 366 if $self->IsLeapYear();
}

sub DaysLeftInYear
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
	my $days = $self->DaysInYear();
	my $day = $self->DayOfYear();

	return $days - $day;
}	

sub LastDayOfMonth
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
	if($self->Day() >= $self->DaysInMonth())
	{
		return 1;
	}
		
}

sub IsLeapYear
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();
	my $year = $self->Year();

	return 1 if(!($year % 400));
	return 0 if(($year %100));
	return 1 if(!($year % 4));
	return 0;
}

sub Array2Epoch
{
	my $self = shift;
	my $input = shift;

	my ($y,$m,$d,$h,$mm,$ss) = @{$input}[0,1,2,3,4,5];

	local $ENV{'TZ'} = $self->TimeZone();
	return mktime(
							$ss || 0, 
							$mm || 0, 
							$h || 0, 
							$d || 1,
							($m || 1)-1,
							($y || 2000)-1900,
							0,
							0,
							-1);
}


#Oveload methods.

sub AsScalar { return shift->TimeFormat(); }
sub AsNumber { return shift->{epoch}; }

sub AsArray
{
	my $self = shift;

	local $ENV{'TZ'} = $self->TimeZone();

	my ($ss,$mm,$h,$d,$m,$y) = localtime($self->{epoch});
	$y += 1900;
	$m += 1;

	return [ $y,$m,$d,$h,$mm,$ss];
}

sub AsHash
{
	my $self = shift;

	my $self_array = $self->AsArray();

	return {
				year => $self_array->[0],
				month => $self_array->[1],
				day => $self_array->[2],
				hour => $self_array->[3],
				min => $self_array->[4],
				sec => $self_array->[5],
			};
}


sub Add 
{
	my ($self, $delta) = @_;

	if(!ref($delta))
	{
		my $epoch = $self->Epoch();
		$epoch += $delta;
		$self->Epoch($epoch);
		return $self;
	}
	elsif($delta->isa($self->DELTA_CLASS()))
	{
		local $ENV{'TZ'} = $self->TimeZone();

		my $epoch = $self->{epoch};

		my $newdate = new Date::Handler({ date => $epoch, time_zone => $self->TimeZone() });

		#Take care of the seconds.
		$epoch += $delta->Seconds();
		$newdate->Epoch($epoch);

		my $self_array = $newdate->AsArray();
		#Take care of the months.
		$self_array->[1] += $delta->Months();

		my $years = floor(($self_array->[1]-1)/12);
		$self_array->[1] -= 12*$years;

		#Take care of the years.
		$self_array->[0] += $years;

		my $return_date =  new Date::Handler({ date => $self_array, time_zone => $self->TimeZone() });
			
		return $return_date;

	}
	else
	{
		croak "Trying to add/substract an unknown object to a Date::Handler";
	}
}


sub Sub
{
	my ($self, $delta) = @_;

	if(!ref($delta))
	{
		my $epoch = $self->Epoch();
		$epoch -= $delta;
		$self->Epoch($epoch);
		return $self;
	}
	elsif($delta->isa($self->DELTA_CLASS()))
	{
		return $self->Add(-$delta);
	}
	elsif($delta->isa('Date::Handler'))
	{

		#my $s_month = $delta->Month();
		#my $e_month = $self->Month();
		#my $s_year = $delta->Year();
		#my $e_year = $self->Year();
#
#		my $years = $e_year - $s_year;
#		my $months = $e_month - $s_month + (12 * $years);

		
		my $seconds = $self->Epoch() - $delta->Epoch();

		if(($self->DayLightSavings() && !$delta->DayLightSavings()) ||
		   !$self->DayLightSavings() && $delta->DayLightSavings())	
		{
			$seconds += 3600;
		}

		return Date::Handler::Delta->new($seconds);
	}
	else
	{
		croak "Cannot substract something else than a ".$self->DELTA_CLASS()." or Date::Handler or constant from a Date::Handler";
	}
}


sub Cmp 
{
	my ($self, $date, $reverse) = @_;

	my $cmp_date;

	if(!ref($date))
	{
		$cmp_date = $date;
	}
	elsif($date->isa('Date::Handler'))
	{
		$cmp_date = $date->{epoch};
	}
	elsif($date->isa($self->DELTA_CLASS()))
	{
		croak "Cannot compare a Date::Handler to a Delta.";
	}
	else
	{
		croak "Trying to compare a Date::Handler to an unknown object.";
	}
		
	return $self->{epoch} <=> $cmp_date;
}

sub Incr
{
	my ($self) = @_;

	my $epoch = $self->{epoch};
	$epoch++;

	return new Date::Handler({ date => $epoch, time_zone => $self->TimeZone() });
}


sub AllInfo
{
	my $self = shift;
	my $out_string;

	local $ENV{'TZ'} = $self->TimeZone();

	$out_string .= $self->LocalTime()."\n";
	$out_string .= $self->TimeFormat()."\n";
	$out_string .= "Epoch: ".$self->Epoch()."\n";
	$out_string .= "TimeZone: ".$self->TimeZone()." (".$self->TimeZoneName().")\n";
	$out_string .= "DayLightSavings: ".$self->DayLightSavings()."\n";
	$out_string .= "GMT Time: ".$self->GmtTime()."\n";	
	$out_string .= "GmtOffset: ".$self->GmtOffset()." (".($self->GmtOffset() / 60 / 60).")\n";
	$out_string .= "Year: ".$self->Year()."\n";
	$out_string .= "Month: ".$self->Month()."\n";
	$out_string .= "Day: ".$self->Day()."\n";
	$out_string .= "Hour: ".$self->Hour()."\n";
	$out_string .= "Min: ".$self->Min()."\n";
	$out_string .= "Sec: ".$self->Sec()."\n";
	$out_string .= "WeekDay: ".$self->WeekDay()."\n";
	$out_string .= "WeekDayName: ".$self->WeekDayName()."\n";
	$out_string .= "FirstWeekDayOfMonth: ".$self->FirstWeekDayOfMonth()."\n";
	$out_string .= "WeekOfMonth: ".$self->WeekOfMonth()."\n";
	$out_string .= "DayOfYear: ".$self->DayOfYear()."\n";
	$out_string .= "MonthName: ".$self->MonthName()."\n";
	$out_string .= "DaysInMonth: ".$self->DaysInMonth()."\n";
	$out_string .= "Leap Year: ".$self->IsLeapYear()."\n";
	$out_string .= "DaysInYear: ".$self->DaysInYear()."\n";
	$out_string .= "DaysLeftInYear: ".$self->DaysLeftInYear()."\n";
	$out_string .= "\n\n";
	return $out_string;
}

666;
__END__
