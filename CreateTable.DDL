CREATE TABLE "CMDB"."LDBINFO"  (
		  "LDBID" INTEGER ,
		  "VIP" VARCHAR(32 OCTETS) ,
		  "PORT" INTEGER ,
		  "DBNAME" VARCHAR(32 OCTETS) ,
		  "DBUSER" VARCHAR(32 OCTETS) ,
		  "DBPASS" VARCHAR(32 OCTETS) ,
		  "UIDAPP" VARCHAR(32 OCTETS) ,
		  "DBALIAS" VARCHAR(128 OCTETS) ,
		  "VALID" CHAR(1 OCTETS) ,
		  "UIDLASTUPDATETIME" TIMESTAMP ,
		  "UIDFLAG" CHAR(1 OCTETS) )
		 ORGANIZE BY ROW;

CREATE TABLE "DBI"."DBUID"  (
		  "LDBID" INTEGER ,
		  "VIP" VARCHAR(32 OCTETS) NOT NULL ,
		  "PORT" INTEGER NOT NULL ,
		  "DBNAME" VARCHAR(32 OCTETS) NOT NULL ,
		  "STATUS" INTEGER ,
		  "PHASE" VARCHAR(128 OCTETS) ,
		  "LASTUPDATETIME" TIMESTAMP ,
		  "UIDAPP" VARCHAR(32 OCTETS) NOT NULL ,
		  "MESSAGE" VARCHAR(1024 OCTETS) ,
		  "LASTCONNECTTIME" TIMESTAMP )
		 ORGANIZE BY ROW;

CREATE OR REPLACE VIEW DBI.V_DBUIDLIST AS
	WITH L(DBNAME,DBALIAS,LDBID,DBUSER,DBPASS,UIDAPPLIST,ADVANCEUIDAPP,UIDFLAG,VALID,
			VIP,PORT,FULLVIP,SP,P,LEVEL)
	AS (
		SELECT DBNAME,DBALIAS,LDBID,DBUSER,DBPASS,
					 NULLIF(TRIM(UIDAPP),'') UIDAPPLIST,
					 CASE WHEN UIDAPP LIKE '%'||ADVANCEUIDAPP||'%' OR NULLIF(TRIM(UIDAPP),'') IS NULL THEN ADVANCEUIDAPP ELSE NULL END AS ADVANCEUIDAPP,
			UIDFLAG,VALID,
					 SUBSTR(VIP,1,CASE WHEN LOCATE(',',VIP)>0 THEN LOCATE(',',VIP)-1 ELSE LENGTH(VIP) END) VIP,
			PORT,TRIM(VIP) FULLVIP,1 AS SP,LOCATE(',',VIP) AS P,1 AS LEVEL
		FROM CMDB.LDBINFO WHERE VALID='Y'
		UNION ALL
		SELECT DBNAME,DBALIAS,LDBID,DBUSER,DBPASS,UIDAPPLIST,ADVANCEUIDAPP,UIDFLAG,VALID,
									 SUBSTR(FULLVIP,P+1,CASE WHEN LOCATE(',',FULLVIP,P+1)>0 THEN
										 LOCATE(',',FULLVIP,P+1)-(P+1) ELSE LENGTH(FULLVIP)-P END) VIP,
			PORT,FULLVIP,P+1 AS SP,LOCATE(',',FULLVIP,P+1) AS P,LEVEL+1 LEVEL
		FROM L WHERE P>0 AND LEVEL<10
	)
	SELECT DBNAME,NVL(DBALIAS,DBNAME) AS DBALIAS,LDBID,DBUSER,DBPASS,UIDAPPLIST,
		ADVANCEUIDAPP,UIDFLAG,VALID,FULLVIP,PORT,VIP,STATUS,UIDAPP,LASTUPDATETIME,
								ROW_NUMBER() OVER (PARTITION BY DBNAME,LDBID ORDER BY DECODE(STATUS,0,0,-1) DESC NULLS LAST,
									HASHID NULLS LAST,VIP NULLS LAST) RID
	FROM
		(SELECT L.DBNAME,L.DBALIAS,L.LDBID,L.DBUSER,L.DBPASS,
			 L.UIDAPPLIST,L.ADVANCEUIDAPP,L.UIDFLAG,L.VALID,L.FULLVIP,L.PORT,
			 CAST(L.VIP AS VARCHAR(15)) AS VIP,NVL(I.STATUS,-1) STATUS,
			 CAST(I.UIDAPP AS VARCHAR(16)) AS UIDAPP,I.LASTUPDATETIME,
			 CASE WHEN I.UIDAPP IS NULL THEN NULL WHEN I.UIDAPP=L.ADVANCEUIDAPP THEN -1
			 ELSE MOD(DBMS_UTILITY.GET_HASH_VALUE(L.DBNAME||I.UIDAPP,1,256),9) END AS HASHID
		 FROM L LEFT JOIN DBI.DBUID I ON (L.DBNAME,L.LDBID,L.VIP,L.PORT)=(I.DBNAME,I.LDBID,I.VIP,I.PORT)
																		 AND I.STATUS=0 AND I.LASTUPDATETIME>CURRENT TIMESTAMP-60 SECONDS WHERE L.LEVEL<10);