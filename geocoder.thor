# Copyright 2009 Daniel Rodríguez Troitiño.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

class Geocoder < Thor
  GEONAMES_DUMP_BASE_URL = 'http://download.geonames.org/export/dump/'
  GEONAMES_COUNTRY_INFO = 'countryInfo.txt'
  GEONAMES_ADMIN1_INFO = 'admin1CodesASCII.txt'
  
  DEFAULT_LOCALE = 'en_US'
  
  CSV_OPTIONS = { :col_sep => "\t" }
  CITIES_CSV_OPTIONS = {
    :headers => %w(geonameid name asciiname alternatenames latitude longitude feature_class feature_code country_code cc2 admin1_code admin2_code admin3_code admin4_code population elevation gtopo30 timezone modification_date),
    :quote_char => '$', # bogus character
  }
  ADMIN1_CSV_OPTIONS = {
    :headers => %w(code name asciiname geonameid),
  }
  COUNTRIES_CSV_OPTIONS = {
    :headers => %w(ISO ISO3 ISO_numeric fips country capital area population continent tld currency_code currency_name phone postal_code_format postal_code_regex languages geonameid neighbours equivalent_fips_code),
  }
  
  DATABASE_SCHEMA_VERSION = 1
  
  CODE_BASE_URL = "https://raw.githubusercontent.com/murrple-1/reversegeocoding/master/%file%"
  RG_LOCATION_M_FILE = "RGLocation.m"
  RG_LOCATION_H_FILE = "RGLocation.h"
  RG_REVERSEGEOCODER_M_FILE = "RGReverseGeocoder.m"
  RG_REVERSEGEOCODER_H_FILE = "RGReverseGeocoder.h"
  RG_CONFIG_FILE = "RGConfig.h"
  
  desc "download all|code|cities|admin1s|countries", "Download the code or the GeoNames database dump for the specified file. Possible files are cities1000.zip, cities5000.zip, cities15000.zip or allCountries.zip"
  method_options :citiesFile => 'cities1000.zip', :dest => :optional
  def download(what)
    case what.downcase
    when 'code'
      download_code(options['dest'])
    when 'cities'
      download_cities(options['citiesFile'], options['dest'])
    when 'admin1s'
      download_admin1s(options['dest'])
    when 'countries'
      download_countries(options['dest'])
    when 'all'
      download_cities(options['size'])
      download_admin1s()
      download_countries()
      download_code()
    else
      task = self.class.tasks['download']
      puts task.formatted_usage(self.class, false)
      puts task.description
    end
  end
  
  desc "database", "Read GeoNames database dumps and transforms it into a SQLite database."
  method_options :from => 'cities5000.txt', :to => 'geodata.sqlite', :countries => 'countryInfo.txt', :admin1s => 'admin1CodesASCII.txt', :level => 10
  def database()
    from = options['from']
    to = options['to']
    countries = options['countries']
    admin1s = options['admin1s']
    level = options['level']
    
    if !File.exists?(from)
      puts "#{from} does not exist. It is required for city data"
      exit
    end
      
    if !File.exists?(countries)
      puts "#{countries} does not exist. It is required for country data"
      exit
    end
    
    require 'csv'
    require 'sqlite3'
    
    puts "Creating database..."
    db = create_database(to)
#   db = get_database(to)
	create_localize_table(db)
    create_countries_table(db)
    create_admin1s_table(db)
    create_cities_table(db)
    puts "Inserting countries data..."
    countries_ids = insert_countries(db, countries)
    puts "Inserting admin1s data..."
    admin1s_ids = insert_admin1s(db, admin1s)
    puts "Inserting cities data (this could take a while)..."
    insert_cities(db, from, level, countries_ids, admin1s_ids)
    close_database(db)
    puts "Compressing database..."
    `gzip -9 < "#{options['to']}" > "#{options['to']}.gz"`
  end
  
  desc "auxiliary", "Create the auxiliary files (Plist and Header)"
  method_options :from => 'cities5000.txt', :to => 'geodata.sqlite', :level => 10
  def auxiliary()
    from = options['from']
    to = options['to']
    level = options['level']
    
    if !File.exists?(from)
      puts "#{from} does not exist. It is required"
      exit
    end
    
    if !File.exists?(to)
      puts "#{to} does not exist. It is required"
      exit
    end
    
    puts "Creating metadata file..."
    create_plist_file(to, from, level)
    puts "Creating RGConfig.h file..."
    create_header_file(to, from, level)
  end
  
private
  def download_cities(citiesFile, dest = nil)
    dest = dest.nil? ? citiesFile : dest
    dest = File.join(dest, citiesFile) if File.directory?(dest)
    download_url(GEONAMES_DUMP_BASE_URL + citiesFile, dest)
    `unzip -o "#{dest}" -d #{File.dirname(dest)}`
  end
  
  def download_admin1s(dest = nil)
    filename = GEONAMES_ADMIN1_INFO
    dest = dest.nil? ? filename : dest
    dest = File.join(dest.filename) if File.directory?(dest)
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
  end
  
  def download_countries(dest = nil)
    filename = GEONAMES_COUNTRY_INFO
    dest = dest.nil? ? filename : dest
    dest = File.join(dest, filename) if File.directory?(dest)
    download_url(GEONAMES_DUMP_BASE_URL + filename, dest)
  end
  
  def download_code(dest = nil)
    dest = dest.nil? ? '.' : dest
    dest = File.dirname(dest) unless File.directory?(dest)
    download_url(CODE_BASE_URL.gsub('%file%', RG_REVERSEGEOCODER_M_FILE), File.join(dest, RG_REVERSEGEOCODER_M_FILE))
    download_url(CODE_BASE_URL.gsub('%file%', RG_REVERSEGEOCODER_H_FILE), File.join(dest, RG_REVERSEGEOCODER_H_FILE))
    download_url(CODE_BASE_URL.gsub('%file%', RG_LOCATION_M_FILE), File.join(dest, RG_LOCATION_M_FILE))
    download_url(CODE_BASE_URL.gsub('%file%', RG_LOCATION_H_FILE), File.join(dest, RG_LOCATION_H_FILE))
  end
  
  def download_url(url, dest)
    puts "Downloading #{url} -> #{dest}"
    `curl -o "#{dest}" "#{url}"`
  end
  
  
  
  # Database functions
  
  def sector_xy(lat, lon, r = 10)
    # We suppose latitude is also [-180,180] so the sector are squares
    lat += 180
    lon += 180

    [(2**r*lat/360.0).floor, (2**r*lon/360.0).floor]
  end
  
  def hilbert_distance(x, y, r = 10)
    # from Hacker's delight Figure 14-10
    s = 0

    r.downto(0) do |i|
      xi = (x >> i) & 1 # Get bit i of x
      yi = (y >> i) & 1 # Get bit i of y

      if yi == 0
        temp = x         # Swap x and y and,
        x = y ^ (-xi)    # if xi = 1,
        y = temp ^ (-xi) # complement them.
      end
      s = 4*s + 2*xi + (xi ^ yi) # Append two bits to s.
    end

    s
  end
  
  def create_database(to)
    if File.exists?(to)
      puts "File '#{to}' already exist. Please move away the file or remove it."
      exit
    end
    
    SQLite3::Database.new(to)
  end
  
  def get_database(to)
    SQLite3::Database.new(to)
  end
  
  def create_localize_table(db)
  	db.execute(<<-SQL)
  	CREATE TABLE localize (
  		text TEXT,
  		locale TEXT,
  		localizedText TEXT NOT NULL,
  		PRIMARY KEY (text, locale)
  	)
  	SQL
  end
  
  def create_countries_table(db)
    db.execute(<<-SQL)
    CREATE TABLE countries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
    SQL
  end
  
  def create_admin1s_table(db)
    db.execute(<<-SQL)
    CREATE TABLE admin1s (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT NOT NULL
    )
    SQL
  end
  
  def create_cities_table(db)
    db.execute(<<-SQL)
    CREATE TABLE cities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      sector INTEGER NOT NULL,
      country_id INTEGER NOT NULL,
      admin1_id INTEGER
    )
    SQL
    db.execute("CREATE INDEX IF NOT EXISTS cities_sector_idx ON cities (sector)")
  end
  
  def insert_countries(db, countries)
    ids = Hash.new
    country_insert = db.prepare("INSERT INTO countries (name) VALUES (:name)")
    open(countries, 'rb') do |io|
      io.rewind unless io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
      io.readline while io.read(1) == '#' # Skip comments at the start of the file
      io.seek(-1, IO::SEEK_CUR) # Unread the last character that wasn't '#'
      csv = CSV.new(io, CSV_OPTIONS.merge(COUNTRIES_CSV_OPTIONS))
      csv.each do |row|
        country_insert.execute :name => row['country']
        ids[row['ISO']] = db.last_insert_row_id
      end
    end
    country_insert.close
    
    ids
  end
  
  def insert_admin1s(db, admin1s)
    ids = Hash.new
    admin1_insert = db.prepare("INSERT INTO admin1s (name, code) VALUES (:name, :code)")
    open(admin1s, 'rb') do |io|
      io.rewind unless io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
      io.readline while io.read(1) == '#' # Skip comments at the start of the file
      io.seek(-1, IO::SEEK_CUR) # Unread the last character that wasn't '#'
      csv = CSV.new(io, CSV_OPTIONS.merge(ADMIN1_CSV_OPTIONS))
      csv.each do |row|
      	name = row['name']
      	code = row['code']
      	next if name.nil? || code.nil?
        admin1_insert.execute :name => name, :code => code
        ids[row['code']] = db.last_insert_row_id
      end
    end
    admin1_insert.close
    
    ids
  end
  
  def insert_cities(db, from, level, countries_ids, admin1s_ids)
    city_insert = db.prepare("INSERT INTO cities (name, latitude, longitude, sector, country_id, admin1_id) VALUES (:name, :latitude, :longitude, :sector, :country_id, :admin1_id)")
    open(from, 'rb') do |io|
      io.rewind unless io.read(3) == "\xef\xbb\xbf" # Skip UTF-8 marker
      io.readline while io.read(1) == '#' # Skip comments at the start of the file
      io.seek(-1, IO::SEEK_CUR) # Unread the last character that wasn't '#'
      csv = CSV.new(io, CSV_OPTIONS.merge(CITIES_CSV_OPTIONS))
      csv.each do |row|
        next if denyRow? row
        country_code = row['country_code']
        admin1_code = row['admin1_code']
        country_id = countries_ids[country_code]
        admin1_id = admin1_code.nil? ? nil : admin1s_ids[country_code + "." + admin1_code]
        lon, lat = row['longitude'].to_f, row['latitude'].to_f
        x, y = sector_xy(lat, lon, level)
        sector = hilbert_distance(x, y, level)
        city_insert.execute :name => row['name'], :latitude => lat, :longitude => lon, :country_id => country_id, :admin1_id => admin1_id, :sector => sector
      end
    end
    
    city_insert.close
  end
  
  # any criteria for the entry should be entered here
  def denyRow?(row)
    feature_class = row['feature_class']
    if feature_class != 'P'
      return true
    end
    return false
  end
  
  def close_database(db)
    db.execute('VACUUM')
    db.close
  end
  
  def create_plist_file(to, from, level)
    require 'cfpropertylist'
    
    db_version = File.mtime(from).strftime('%Y%m%d%H%M%S')
    schema_version = DATABASE_SCHEMA_VERSION
    
    dict = {"database_version" => "#{db_version}",
          "schema_version" => schema_version,
          "database_level" => level
        }
    
    plist = CFPropertyList::List.new
    plist.value = CFPropertyList.guess(dict)
    plist.save(to + ".plist", CFPropertyList::List::FORMAT_BINARY)
  end
  
  def create_header_file(to, from, level)
    db_version = File.mtime(from).strftime('%Y%m%d%H%M%S')
    schema_version = DATABASE_SCHEMA_VERSION
    
    open(RG_CONFIG_FILE, 'wb') do |io|
      io.write(<<-HEADER)
      #ifndef RGCONFIG
      #define RGCONFIG

      #define DATABASE_VERSION #{db_version}
      #define SCHEMA_VERSION #{schema_version}
      #define DATABASE_LEVEL #{level}
      #define DATABASE_FILENAME @"#{to}"

      #endif
      HEADER
    end
  end
end
