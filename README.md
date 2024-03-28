# scripts
My useful small scripts toolbox

Simple, small, easy to use, but you should install libraries in need. 

## dirchk.bat
A wrapped PYTHON script. It use MD5 digest to check if files are corrupted, just like the famous "md5sum", but it directly supports directories and subdirectories, and comprehensively checks the modification time and size of the file.

If a new file is detected, a new record is generated, and is marked as "NEW".
If a file in records is deleted, the corresponding record is not deleted, but is marked as "DEL".
If modify time or size of a file was changed, the corresponding record is updated, and is marked as "UPD".
If the MD5 digest of a file is changed, the corresponding record is not upadated, but is marked as "BAD".
Records of other files are marked as "GUD".
If I/O error occurs when calculating MD5 digest, the corresponding MD5 digest is 32 times of "-"

Usage: dirchk.bat [Options] <directory to be checked, which must be explicitly specified>
Example: python C:\SHELL\Tool\dirchk.bat d:\data
Options:
  -f <the record file contains MD5 digest> : defaultly a file named '._dirchk' in the directory is used  if not specified here
  -o <the output file contains MD5 digest> : defaultly using the same file as "-f" specified
  -d <days> : defaultly 30. Not-modified files that have just been checked in the these days are excluded from the MD5 re-calculation
  -B : do not backup records when output file name is same as original record file name
  -P : do not print progress information
  -x : delete records marked as 'DEL'

## filter.bat
A wrapped PYTHON applet. It uses tkinter to provide windows UI, and uses scipy and matplotlib to provide FFT ploting, filter designing and data filtering.
Several IIR and FIR methods are provided.

## photoname.bat
A wrapped PERL script. To sort photos by create time in EXIF infomation. Image::ExifTool is required

Usage: photoname <dir>
rename .jpg files to YYYYMMDD-###-where-what [.jpg/tiff/tiff/dng/nef], sub-folders is included

## regren.bat
A wrapped PERL script. Using regular expressions to rename files in bulk.

Usage: regren.bat [-itrd] <old file name to match> <new name to apply>
 rename files use regular express
 i:ignore case
 t:test only
 r:recur subdir
 d:change directory name only
 a:add number when conflicted


