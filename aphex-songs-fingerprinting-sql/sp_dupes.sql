DELIMITER //
DROP PROCEDURE IF EXISTS `find_dupe_songs`//
CREATE PROCEDURE find_dupe_songs()
 BEGIN
 
 	DECLARE done BOOLEAN;
	DECLARE s_id INT;
	DECLARE total INT;
	DECLARE current INT;
	DECLARE song_cursor CURSOR FOR
		SELECT	
			id
		FROM 
			songs
		WHERE 
			collection = 'megashit'
		;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done := TRUE;

	SET current = (SELECT 0);
	SET total = (SELECT count(*) FROM songs WHERE collection='megashit');

	DELETE FROM results;

 	-- Read the rows in
	OPEN song_cursor;
	
	read_loop: LOOP
		FETCH song_cursor INTO s_id;
		IF done THEN
			LEAVE read_loop;
		END IF;

		SET current = (SELECT current + 1);
		SELECT CONCAT('Looking up song_id: ', s_id, ' Current: ', current, ' Total: ', total, ' - ', ROUND(current/total*100,2), '% done' );

		-- Lookup dupe songs
		INSERT INTO results
		SELECT 
			   NULL,
			   y.songid as first_songid, 
			   y.c_songid as second_songid,
			   CONCAT(y.collection,'/',sy.filename) AS one,
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
		      WHERE songid =s_id ) x
		   JOIN fingerprints f ON (x.pos=f.pos)
		   JOIN songs s ON (f.songid=s.id)
		   WHERE s.collection != 'megashit') y
		JOIN songs sy ON (sy.id=y.songid)
		JOIN songs ss ON (ss.id=y.c_songid)
		GROUP BY y.songid HAVING SUM(y.score) < 10000 and len_check < 1
		ORDER BY SUM(y.score), len_check 
		LIMIT 1 ;
	END LOOP read_loop;
	

 END
//

DELIMITER ;




