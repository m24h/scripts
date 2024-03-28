0<0# : ^
''' 
@python %~f0 %* 
@goto :eof
'''

import os
import sys
import getopt
import hashlib
import datetime
import time
import re

md5_err='-'*32
md5_total_bytes=0
def md5(fname):
	global md5_total_bytes
	m = hashlib.md5()
	try:
		with open(fname,'rb') as f :
			while d:=f.read(32768) :
				m.update(d)
				md5_total_bytes=md5_total_bytes+len(d)
		return m.hexdigest().upper()
	except Exception as e:
		print('{0} : {1}'.format(e, fname), file=sys.stderr)
		return md5_err

#record:(check_date, mark, modify_time, size, MD5)
pattern=re.compile(r'^(\d+)-(\d+)-(\d+)\s+(\w+)\s+(\d+)-(\d+)-(\d+):(\d+):(\d+):(\d+)\.(\d+)\s+(\d+)\s+([0-9A-Fa-f]{32})\s+(.+)$')
def record_parse(line):
	if m:=pattern.match(line) :
		return (m.group(14), \
		        (datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3))), \
						 m.group(4), \
						 datetime.datetime(int(m.group(5)), int(m.group(6)), int(m.group(7)),int(m.group(8)), int(m.group(9)), int(m.group(10)), int(m.group(11))), \
						 int(m.group(12)), \
						 m.group(13).upper() \
						) \
					 )
	return (None, None)

format='{0:04d}-{1:02d}-{2:02d} {3:<3} {4:04d}-{5:02d}-{6:02d}:{7:02d}:{8:02d}:{9:02d}.{10:06d} {11:>16} {12:<32} {13}' 
def record_format(fname, rec):
	return format.format(rec[0].year, rec[0].month, rec[0].day, \
	                     rec[1], \
	                     rec[2].year, rec[2].month, rec[2].day, rec[2].hour, rec[2].minute, rec[2].second, rec[2].microsecond, \
	                     rec[3], \
	                     rec[4], \
	                     fname)
												  
if __name__ != '__main__':
	exit(0)

try:
	opts, args = getopt.getopt(sys.argv[1:], 'f:o:d:n:BPx')
except Exception as e:
	print(e, file=sys.stderr)
	exit(1)
	
if not args or len(args)!=1:
	print('''\
Check files in a directory and its recursive subdirectories using MD5 digest algorithm. \
This script will use a file to record MD5 digest of all the files under the directory, and following rules is adopted.

If a new file is detected, a new record is generated, and is marked as "NEW". 
If a file in records is deleted, the corresponding record is not deleted, but is marked as "DEL". 
If modify time or size of a file was changed, the corresponding record is updated, and is marked as "UPD". 
If the MD5 digest of a file is changed, the corresponding record is not upadated, but is marked as "BAD".
Records of other files are marked as "GUD".
If I/O error occurs when calculating MD5 digest, the corresponding MD5 digest is 32 times of "-"

Usage: python {0} [Options] <directory to be checked, which must be explicitly specified>
Example: python {0} d:\\data
Options:
  -f <the record file contains MD5 digest> : defaultly a file named '._dirchk' in the directory is used  if not specified here
  -o <the output file contains MD5 digest> : defaultly using the same file as "-f" specified
  -d <days> : if specified, Not-modified files that have just been checked in the these days are excluded from the MD5 re-calculation
  -n <bytes> : if specified, MD5 re-calculation are no longer performed when the total bytes of MD5 calculation reaches this value
  -B : do not backup records when output file name is same as original record file name
  -P : do not print progress information
  -x : delete records marked as 'DEL'\
	'''.format(sys.argv[0]), file=sys.stderr)
	exit(1)

#check dir
directory=args[0].strip()
if len(directory)==0:
	directory='.'
elif len(directory)>1:
	directory=directory[0:1]+directory[1:].rstrip('\\').rstrip('/')
if not os.path.exists(directory) :
	print('Directory "{0}" does not exist'.format(directory), file=sys.stderr)
	exit(1)
elif not os.path.isdir(directory) :
	print('"{0}" is not a directory'.format(directory), file=sys.stderr)
	exit(1)

#get other parameters
rec_file=os.path.join(directory, '._dirchk')
out_file=None
days=0
bytes_limit=-1
backup=1
progress=1
clean=0
for n, v in opts:
	if n in ('-B',):
		backup=0
	elif n in ('-P',):
		progress=0
	elif n in ('-x',):
		clean=1
	elif n in ("-f",): 
		rec_file=v
	elif n in ("-o",): 
		out_file=v
	elif n in ('-d',):
		try:
			days=int(v)
		except:
			print('"{0}" is not a number for "-d"'.format(v), file=sys.stderr)
			exit(1)
	elif n in ('-n',):
		try:
			bytes_limit=int(v)
		except:
			print('"{0}" is not a number for "-n"'.format(v), file=sys.stderr)
			exit(1)
if not out_file:
	out_file=rec_file

#check output file permission
out_dir=os.path.dirname(out_file)
if not out_dir:
	out_dir='.'
if not os.access(out_dir, os.W_OK):
	print('Output directory is not writable : {0}'.format(out_dir), file=sys.stderr)
	exit(1)

#check date
now=datetime.datetime.now()
today=now.date()
print('Check date: {0:04d}-{1:02d}-{2:02d}'.format(today.year, today.month, today.day), file=sys.stderr)

#read records from specifiled file
#format: check_date mark modify_time size md5_hex file_name
records=dict()
rec_file_exists=0
if os.path.exists(rec_file) :
	rec_file_exists=1
	if not os.path.isfile(rec_file) :
		print('"{0}" is not a file'.format(rec_file), file=sys.stderr)
		exit(1)
	num=0
	t1=time.time()
	try:
		print('Read record file: {0}'.format(rec_file), file=sys.stderr)		
		with open(rec_file, 'r', encoding='utf-8') as f:
			for line in f:
				if not (line:=line.strip()) :
					continue
				fname, rec=record_parse(line)
				if not fname or not rec:
					print('Bad record line {0} : {1}'.format(num+1, line), file=sys.stderr)
					exit(1)
				records[fname]=rec
				num=num+1
				if progress and (t2:=time.time())-t1>1:
					t1=t2
					sys.stderr.write('Records read : {0}/{1}\r'.format(len(records), num))
					sys.stderr.flush()
		print('Records read : {0}/{1}'.format(len(records), num), file=sys.stderr)		
	except Exception as e:
		print(e)
		exit(1)

#scan directory, get mtime (or ctime if failed to get mtime)
scanned=dict()
print('Scan directory : {0}'.format(directory), file=sys.stderr)
num=0
t1=time.time()
try:
	for root, dirs, files in os.walk(directory):
		for file in files:
			f=os.path.join(root, file)
			st=os.stat(f)
			t=st.st_mtime
			if t<0:
				t=st.st_ctime
			if t<0:
				t=0
			scanned[f]=(datetime.datetime.fromtimestamp(t), st.st_size)
			num=num+1
			if progress and (t2:=time.time())-t1>1:
				t1=t2
				sys.stderr.write('Files scanned : {0}/{1}\r'.format(len(scanned), num))
				sys.stderr.flush()
	print('Files scanned : {0}/{1}'.format(len(scanned), num), file=sys.stderr)
except Exception as e:
	print(e, file=sys.stderr)
	exit(1)

#backup
if backup and rec_file_exists and os.path.abspath(rec_file)==os.path.abspath(out_file):
	try:
		newname='{0}.{1:04d}{2:02d}{3:02d}.{4:02d}{5:02d}{6:02d}'.format(rec_file, now.year, now.month, now.day, now.hour, now.minute, now.second)
		os.rename(rec_file, newname)
		print('Rename old record file : {0}'.format(newname), file=sys.stderr)
	except Exception as e:
		print(e, file=sys.stderr)
		exit(1)

#prepare output file
try:
	if out_file=='-':
		out=sys.stdout
	else:
		out=open(out_file, 'w', encoding='utf-8')
except Exception as e:
	print(e, file=sys.stderr)
	exit(1)
		
#check files according to the rules
files=set(records.keys())
files.update(scanned.keys())
print('Checking records and files : {0}'.format(len(files)), file=sys.stderr)
num=0
bytes_done=0
bytes_recalc=0
t1=time.time()
for f in sorted(files):
	if f in records:
		rec=records[f]
		mark=rec[1]
		if f in scanned:
			sc=scanned[f]
			if rec[1]=='DEL':
				print(record_format(f, (today, 'NEW', sc[0], sc[1], md5(f))), file=out)
			elif rec[2]!=sc[0] or rec[3]!=sc[1]:
				print(record_format(f, (today, 'UPD', sc[0], sc[1], md5(f))), file=out)
			elif rec[4]==md5_err:
				if (m:=md5(f))!=md5_err:
					print(record_format(f, (today, rec[1], rec[2], rec[3], m)), file=out)
				else:
					print(record_format(f, rec), file=out)
			elif rec[1]=='BAD':
				if md5(f)==rec[4]:
					print(record_format(f, (today, 'GUD', rec[2], rec[3], rec[4])), file=out)
				else:
					print(record_format(f, rec), file=out)
			elif (bytes_limit<0 or md5_total_bytes<bytes_limit) and (days==0 or (days>0 and (today-rec[0]).days>=days)):
				if (m:=md5(f))!=md5_err:
					if m==rec[4]:
						print(record_format(f, (today, 'GUD', rec[2], rec[3], rec[4])), file=out)
					else:
						print(record_format(f, (today, 'BAD', rec[2], rec[3], rec[4])), file=out)
						print('File may be damaged : {0}'.format(f), file=sys.stderr)
				else:
					print(record_format(f, rec), file=out)
			else:
				print(record_format(f, rec), file=out)
		elif not clean:
			if rec[1]!='DEL':
				print(record_format(f, (today, 'DEL', rec[2], rec[3], rec[4])), file=out)
			else:
				print(record_format(f, rec), file=out)
	else:
		sc=scanned[f]
		print(record_format(f, (today, 'NEW', sc[0], sc[1], md5(f))), file=out)
	num=num+1
	if progress and (t2:=time.time())-t1>1:
		t1=t2
		sys.stderr.write('Records and files checked : {0}/{1}\r'.format(num,  len(files)))
		sys.stderr.flush()
print('Records and files checked : {0}/{1}'.format(num, len(files)), file=sys.stderr)
	
#end output
if out_file!='-':
	out.close()
