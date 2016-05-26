# Aphex songs fingerprinting

This contains an example of using acoustic fingerprinting to find duplicate within two sets of songs. 

## Short Background

Aphex Twin (one of my favorite artists, of which I am a collector), uploaded a bunch of his tracks to soundcloud as user18081974.  However, I was slow at downloading them, and by the time I got around to it, he had removed all his tracks (!). That bastard...   

So, I was forced to scour the internet for complete copies of the works he had uploaded.   

I found two collections, both from megaupload, which I called **megashit** and **megaaudiouser18081974**

The track names and md5 hashes were different, as well as some of the lengths (slightly off, by a second or two).   

I realize I probably could have just compared them by name, or by song length, but I wanted to play with acoustic fingerprinting. 


## Results

So, this is a collection of scripts I used to import both collections into a MySQL database, and then figure out which ones
were duplicates, using acoustic fingerprinting (and track length matching, when the fingerprint was too close to call). 

# Procedure

- First we build a *songs* database, with all of the fingerprinting data from Chromaprint's fpcalc using the 'raw' method. 
- Next separate each fingerprint into a separate *fingerprints* table so each row tracks the COLLECTION/SONGID/FINGERPRINT POSITION/AND FINGERPRINT
- I realize I don't need the fingerprint on the *songs* table...but that point is moot now
- Write a SQL query which does the following:
  - Loops through all songs from a single collection, and compares the fingerprint against all other songs
  - We use an XOR on each of the fingerprint values, and then just count up the number of 1's in the result
  - The lower the score, the better the match. 0 is an exact match, but anything below 1000 is a good bet EXCEPT:
    - Some songs are very short (only a few seconds long), this throws off the fingerprinting results

## Fingerprinting Overview

fpcalc -raw outputs integers which need to be processed in binary.  The numbers correspond to the low, mid, and high frequencies for each timeframe. 1663937366 is an example, which we will compare with 1648212742. 

1663937366 in binary is 1100011001011011010101101010110   
1648212742 in binary is 1100010001111011011101100000110   
   
First we do a logical XOR:   
1100011001011011010101101010110   
1100010001111011011101100000110   
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=   
0000001000100000001000001010000   

Now count the number of 1's:   
000000**1**000**1**0000000**1**00000**1**0**1**0000   

So the difference here is 5.    

We do this for all numbers, adding the results to get the final 'score'.  The lower the score, the closer the match. Generally speaking, anything under 10,000 is a good match, and below 1,000 is a almost sure match.    

**However** pay close attention to the times. A 5 second song may have a close match to a 120 sec song, simply because there's not much data to work with. The above 1,000/10,000 is based on 90 seconds of sampling. 

## Songs

 The basic SQL for looking for duplicates looks like this:
 ```sql
 SELECT CONCAT(y.collection,'/',sy.filename) AS one,
       CONCAT(ss.collection,'/',ss.filename) AS two,
       CONCAT(y.songid,' - ', y.c_songid) AS songids,
       CONCAT(sy.length, ' - ', ss.length) AS length,
       CONCAT(sy.type, '-', sy.bitrate, ' | ', ss.type, '-', ss.bitrate) AS info,
       ABS(sy.length - ss.length) AS len_check,
       IF(ABS(sy.length - ss.length) < 1 AND sy.length - ss.length != 0, 'SIMILAR LENGTHS', IF(sy.length - ss.length = 0, 'SAME LENGTH', 'DIFFERENT LENGTHS')) AS length_check,
       SUM(y.score),
       sy.filename,
       ss.filename
FROM
  (SELECT f.songid AS songid,
  		  x.songid as c_songid,
          s.collection AS collection,
          f.pos AS pos,
          LENGTH(CONV(x.v ^ f.v, 10, 2)) - LENGTH(REPLACE(CONV(x.v ^ f.v, 10, 2), "1", "")) AS score
   FROM
     (SELECT songid,
             pos,
             v
      FROM fingerprints
      WHERE songid = 2 ) x
   JOIN fingerprints f ON (x.pos=f.pos)
   JOIN songs s ON (f.songid=s.id)
   -- JOIN songs ss ON (x.c_songid=ss.id)
   WHERE s.collection != 'megashit') y
JOIN songs sy ON (sy.id=y.songid)
JOIN songs ss ON (ss.id=y.c_songid)
GROUP BY y.songid HAVING SUM(y.score) < 10000 and len_check < 1

```

However, this only compares one song (WHERE songid = 2); 

In order to do a full loop, I wrote a stored procedure to loop through all tracks as a cursor, and then run the above, outputting results to a **results** table

## Final solution

Now, all duplicates are in the **results** table, and we can simply use a WHERE id NOT IN (SELECT songid FROM results) or something similar, to find tracks which are *not* duplicates and exist in only one collection. 


## Notes

I know there's an easier way to do this, but this was suppose to be a challenge in using Acoustic fingerprinting.   This code is left here for good measure. 

### License

All my code here is public domain

### Fair use on music

Aphex twin uploaded all these tracks to soundcloud, before he deleted them.  So I consider it fair use that I am re-uploading these tracks, for the purposes of this demonstration of acoustic fingerprinting.




