#!/usr/bin/perl
package Date::Handler;

use strict;
use Carp;
use Data::Dumper;
use vars qw(@ISA $VERSION);

$VERSION = '0.05';

use POSIX qw(floor strftime mktime);

use Date::Handler::Constants;
use constant DEFAULT_FORMAT_STRING => "%A, %B %e %Y %R:%S (%Z)";
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
	$self->{time_zone} = $args->{time_zone};

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
sub Month { return shift->AsArray()->[1]; }
sub Day { return shift->AsArray()->[2]; }
sub Hour { return shift->AsArray()->[3]; }
sub Min { return shift->AsArray()->[4]; }
sub Sec { return shift->AsArray()->[5]; }

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

		my $years = floor($self_array->[1]/12);
		$self_array->[1] -= 12*$years;

		#Take care of the years.
		$self_array->[0] += $years;

		#Verify if we are the last day of month.
		my $day = $self_array->[2];
		$self_array->[2] = 1;

		my $return =  new Date::Handler({ date => $self_array, time_zone => $self->TimeZone() });
		my $return_array = $return->AsArray();

		if($self->LastDayOfMonth())
		{
			$return_array->[2] = $return->DaysInMonth();
			$return = new Date::Handler({ date => $return_array, time_zone => $return->TimeZone() });
		}
		else
		{
			$return_array->[2] = $day;
			$return = new Date::Handler({ date => $return_array, time_zone => $return->TimeZone() });
		}	
			
		return $return;

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

=head1 NAME

Date::Handler - Easy Date Object

=head1 SYNOPSIS

  use Date::Handler;
 
  my $date = new Date::Handler({ date => time, time_zone => 'Europe/Paris', });
  my $date = new Date::Handler({ date => [2001,04,12,03,01,55], time_zone => 'EST', });
  my $date = new Date::Handler({ date => {
						year => 2001,
						month => 4,
						day => 12,
						hour => 3,
						min => 1,
						sec => 55,
					}, time_zone => 'America/Montreal', });


   print $date;
   print "$date";
   print $date->AllInfo();

   $date->new()				Constructor
   $date->Year()			2001
   $date->Month()			0..11
   $date->Day()				1..31
   $date->Hour()			1..24
   $date->Min()				1..59
   $date->Sec()				1..59
   $date->Epoch($epoch)			Seconds since epoch (GMT)
   $date->TimeZone()			America/Montreal
   $date->TimeZoneName()		EST
   $date->LocalTime()			localtime of the object's epoch 
   $date->TimeFormat($format_string)	strftime
   $date->GmtTime()			gmtime of object's epoch
   $date->UtcTime()			same as GmtTime()
   $date->GmtOffset() 			Offset of object's TZ in seconds
   $date->MonthName()			April
   $date->WeekDay()			1..7 (1 monday)
   $date->WeekDayName()			Wednesday
   $date->FirstWeekDayOfMonth()	1..7
   $date->WeekOfMonth()			1..4
   $date->DaysInMonth()			31,30,29,28 depending on month and year.
   $date->IsLeapYear()			1 if true, 0 if false
   $date->DayLightSavings()		1 if true, 0 if false
   $date->DayOfYear()			Return the day of the year
   $date->DaysInYear()			Returns the number of days in the year.
   $date->DaysLeftInYear()		Returns the number of days remaining in the year
   $date->Array2Epoch([])			Transfer [y,m,d,h,mm,ss] to epoch time
   $date->AsScalar ()			Same as TimeFormat("%A, %B%e %Y %R (%Z)") 
   $date->AsNumber()			same as Epoch()
   $date->AsArray()			Returns [y,m,d,h,mm,ss]
   $date->AsHash()			Returns { year => y, month => m, day => d, hour => h, min => mm, sec => ss }
   $date->AllInfo()			Returns a string containing all of the Object's related information.
   

   my $delta = new Date::Handler::Delta([3,1,10,2,5,5]);
   my $delta = new Date::Handler::Delta({
						years => 3,
						months => 1,
						days => 10,
						hours => 2,
						minutes => 5,
						seconds => 5,
					});
   $delta->new
   $delta->Months() 			Number of months in delta
   $delta->Seconds() 			Number of seconds in delta
   $delta->AsScalar() 			"%d months and %d seconds"
   $delta->AsNumber() 			"%d-%d-%d"
   $delta->AsArray()			[y,m,ss]
   $delta->AsHash()			{ months => m, seconds => ss }

   $date + $delta = Date::Handler
   $date - $delta = Date::Handler
   $date - $date2 = Date::Handler::Delta
   $date + n = (+n seconds)
   $date - n = (-n seconds)

   $delta + $delta = Date::Handler::Delta
   $delta - $delta = Date::Handler::Delta
   $delta * n = Date::Handler::Delta
   $delta / n = Date::Handler::Delta
   $delta + n = (+n seconds)
   $delta - n = (-n seconds)

=head1 DESCRIPTION

Date::Handler is a container for dates that holds all the methods to transform itself
from Timezone to Timezone and format itself. This module idea comes from an original version
written by dLux (Szabó, Balázs) <dlux@kapu.hu> in his module Class::Date.

Date::Handler is implemented in pure Perl using POSIX modules, it encapsulates the environnement variable
TZ for it's time zone management so you don't have to play with it externally in the implementation.

It uses operator overloading and Delta date objects to calculates time differences.

This code is still in it's alpha stage(v0.05) and should not be used on production systems without
reviewing the actual test cases provided with this module in the Date::Handler::Test package.

=head1 IMPLEMENTATION

Using the Date::Handler is simple.

=head2 Creating the absolute Date::Handler

The new() constructor receives only one argument as a hashref:

	my $date = new Date::Handler({
				date => time,
				time_zone => 'Asia/Hong_Kong',
			});

The 'date' key of this argument can be either:

=over 3 

=item * Epoch time

=item * Anonymous array of the form: [y,m,d,h,mm,ss]

=item * A hashref of the form : { year => y,month => m, day => d, hour => h, min => mm, sec => ss }

=back

The 'time_zone' key represents the time zone name this date is considered in.  i.e. Africa/Dakar, EST, PST


=head2 Accessors

You can access the data inside the object using any of the provided methods.
These methods are detailed in the SYNOPSIS up above.


=head2 Modifying the object

A created Date::Handler can be modified on the fly by many ways:

=over 3

=item * Changing the time_zone of the object using TimeZone()

=item * Changing the internal date of the object using Epoch()

=item * By using operators in combination with Date::Handler::Delta objects

=back

Example:

	my $date = new Date::Handler({ date => time });
	$date->TimeZone('Asia/Tokyo');
	print "Time in tokyo: ".$date->LocalTime()."\n";
	$date->Epoch(time);
	$date->TimeZone('America/Montreal');
	print "Time in Montreal: ".$date->LocalTime()."\n";
	$date->TimeZone('GMT');
	print "Greenwich Mean Time: ".$date->LocalTime()."\n";


=head2 Using Date::Handler::Delta objects

To go forward or backward in time with a date object, you can use
the Date::Handler::Delta objects. These objects represent a time lapse
represented in months and seconds. Since Date::Handler uses
operator overloading, you can 'apply' a Delta object on an absolute date
simply by using '+' and '-'.

Example:

	#A Delta of 1 year.
	my $delta = new Date::Handler::Delta([1,0,0,0,0,0]);

	my $date = new Date::Handler({ date => time } );

	#$newdate is now one year in the furure.
	my $newdate = $date+$delta;
	
	
Refer to the Date::Handler::Delta(1) documentation for more on Deltas.


=head2 Operator overload special cases

The Date::Handler overloaded operator have special cases. Refer to the
SYNOPSIS to get a description of each overloaded operator's behaviour.

One special case of the overload is when adding an integer 'n' to a Date::Handler's reference. This is treated as if 'n' was in seconds. Same thing for substraction.

Example Uses of the overload:

	my $date = new Date::Handler({ date =>
					{
						year => 2001,
						month => 5,
						day => 14,
						hour => 5,
						min => 0,
						sec => 0,
					}});
	#Quoted string overload 
	print "Current date is $date\n";
	
	my $delta = new Date::Handler::Delta({ days => 5, });
	
	#'+' overload, now, $date is 5 days in the future.	
	$date += $delta;

	#Small clock. Not too accurate, but still ;)
	while(1)
	{
		#Add one second to the date. (same as $date + 1)
		$date++;
		print "$date\n";
		sleep(1);
	}


=head1 INHERITANCE

A useful way of using Date::Handler in your code is to implement that a class
that ISA Date::Handler. This way you can overload methods through the inheritance
tree and change the object's behaviour to your needs.

Here is a small example of an overloaded class that specifies a default
timezone different than the machine's timezone.

	#!/usr/bin/perl
	package My::Date::Handler;
	
	use strict;
	use vars qw(@ISA $VERSION);
	
	use Date::Handler;
	@ISA = qw(Date::Handler);
	
	use constant DEFAULT_TIME_ZONE => 'Europe/Moscow';
	
	sub TimeZone
	{
		my ($self) = @_;
	
		my $time_zone = $self->SUPER::TimeZone(@_);
	
		return $time_zoneif defined $time_zone;
	
		return $self->DEFAULT_TIME_ZONE();
	}	
	
	1;
	__END__
		
=head1 BUGS (known)

Dates after 2038 are not handled by this module yet. (POSIX)

Dates before 1902 are not handled by this module. (POSIX)

If you find bugs with this module, do not hesitate to contact the author.
Your comments and rants are welcomed :)

=head1 TODO

Add support for dynamic locale using perllocales functions. This will plugin directly with the use of strftime in the Date::Handler and provide locales.

Add a list of supported timezones in the Constants class.Just didnt around
to do it yet :) Feel free :) If you have patches, recommendations or suggestions on this module, please come forward :)

=head1 COPYRIGHT

Copyright(c) 2001 Benoit Beausejour <bbeausej@pobox.com>

All rights reserved. This program is free software; you can redistribute it and/or modify it under the same
terms as Perl itself. 

Portions Copyright (c) Philippe M. Chiasson <gozer@cpan.org>

Portions Copyright (c) Szabó, Balázs <dlux@kapu.hu>

Portions Copyright (c) Larry Rosler 


=head1 AUTHOR

Benoit Beausejour <bbeausej@pobox.com>

=head1 SEE ALSO

Class::Date(1).
Time::Object(1).
Date::Calc(1).
perl(1).

=cut

