Reverse Geocoding
=================

This project a Objective-C class (aim to be used on the iPhone) to include in
your application a reverse geocoding system. Included in the project there is
also a Thor <http://github.com/wycats/thor> script for downloading the cities
database and transforming it into a suitable format for the iPhone.

What's a “reverse geocoding” system?
------------------------------------

As Wikipedia says <http://en.wikipedia.org/wiki/Geocoding>:

> Geocoding is the process of finding associated geographic coordinates … from
> other geographic data, such as street addresses, or zip codes. …
>
> Reverse Geocoding is the opposite: finding an associated textual location
> such a street address, from geographic coordinates.

How do I use it
===============

The project includes a script for Thor <http://github.com/wycats/thor> that
tries to make the use of the project classes and the needed resources as
easy as I can.

This project tries to leverage the tools include in Mac OS X 10.5, but there
are some steps you have to do before using this script. So open your Terminal
and type the following (except the dollar sign):

        $ gem install thor sqlite3 CFPropertyList

After Thor installation you have to install this project Thor script into your
system:

        $ thor install https://raw.githubusercontent.com/murrple-1/reversegeocoding/master/geocoder.thor

When asked, you should say “y” to the question “Do you wish to continue?” and
provide “geocoder” as name for the script in your system.

Once installed you can use Thor anywhere in your system to access the geocoder
tasks. You can get a list of the task typing the following:

        $ thor list geocoder

And you can update the Thor script easily by:

        $ thor update geocoder

The easiest way to use the reverse geocoding system is to use the defaults,
download all (code and databases), and create the SQLite database and the
auxiliary files.

        $ thor geocoder:download all
        $ thor geocoder:database
        $ thor geocoder:auxiliary

Then in your application include the following files:

- <code>RGLocation.h</code>
- <code>RGLocation.m</code>
- <code>RGReverseGeocoder.h</code>
- <code>RGReverseGeocoder.m</code>
- <code>RGConfig.h</code>
- <code>geodata.sqlite.gz</code>
- <code>geodata.sqlite.plist</code>

And also add <code>libsqlite3.dylib</code>, <code>libz.dylib</code> and
<code>CoreLocation.framework</code> to your application.

Then at the start of your application call to:

        [RGReverseGeocoder setupDatabase];

And when you need to get a place from a location:

        [[RGReverseGeocoder sharedGeocoder] placeForLocation:myLocation];

If you need more help look at help from the Thor script, the documentation
of the source code and the example project included in this Git repository.

Advanced
========

If you have want of a complete database, you may want to use the options:

        $ thor geocoder:download all --citiesFile allCountries.zip
        $ thor geocoder:database --from allCountries.txt

This will fill your database with every populated area in the world. Please note, this will take hours.

Also, take a look at the `#denyRow?` function of the thor script (the ruby script is stored in `~/.thor`). It is the filter function for the rows. The provided implementation will filter for only 'P'-class areas. This is a common case, but if you have need of a different filtering, edit this method. If, for example, you wanted only coalfields in your database, you could rewrite the function as:

```ruby
def denyRow?(row)
 feature_code = row['feature_code']
 if feature_code != 'COLF'
  return true
 end
 return false
end
```

See `http://download.geonames.org/export/dump/readme.txt` for more information on the CSV fields.

As an aside, if you are generating your own CSV's (for example, by piping to a new file from `grep`), make sure to change `#denyRow?` to always return false, so it doesn't further filter your results.

---

For anyone interested as well, I have provided a SQL script that adds the more common abbreviations of the USA states and Canada provinces to the `localize` table, after the database has been built. This was useful for me in my projects, but won't be useful for everyone. To use it, run:

        $ sqlite3 geodata.sqlite

Then, within the sqlite3 command line, run:

        > .read US_States_CA_Provinces.sql

Lastly, re-compress the database using:

        $ gzip -9 < geodata.sqlite > geodata.sqlite.gz

It's usage in the code is then:

```objc
CILocation *location = ...
RGLocation *place = [[RGReverseGeocoder sharedGeocoder] placeForLocation:location];
NSString *stateAbbreviation = [[RGReverseGeocoder sharedGeocoder] localizedString:place.admin1Code locale:@""];
```

Credits
=======

Author: Daniel Rodríguez Troitiño (drodrigueztroitino thAT yahoo thOT es)

Updated by Murray Christopherson (murraychristopherson thAT gmail thOT com)

This project could not have been done without the free data provided by
GeoNames <http://geonames.org>. GeoNames data is licensed under a Creative
Commons Attribution 3.0 License <http://creativecommons.org/licenses/by/3.0/>.
The data is provided "as is" without warranty or any representation of
accuracy, timeliness or completeness.

There is a small “inspiration” on some parts of SQLite Persistent Objects for
Cocoa and Cocoa Touch <http://code.google.com/p/sqlitepersistentobjects>.

There is also a method adapted from Figure 14-10 of Hacker's Delight by Henry
S. Warren <http://www.hackersdelight.org/>.
