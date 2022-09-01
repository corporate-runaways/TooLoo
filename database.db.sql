BEGIN TRANSACTION;
CREATE TABLE IF NOT EXISTS "cheats" (
	"id"	INTEGER NOT NULL,
	"command_id"	INTEGER NOT NULL,
	"description"	TEXT NOT NULL,
	"template"	TEXT NOT NULL,
	FOREIGN KEY("command_id") REFERENCES "commands"("id"),
	PRIMARY KEY("id" AUTOINCREMENT)
);
CREATE VIRTUAL TABLE commands_fts USING fts5(
	id,
	name,
	description,
	language
);
CREATE TABLE IF NOT EXISTS "commands_fts_data" (
	"id"	INTEGER,
	"block"	BLOB,
	PRIMARY KEY("id")
);
CREATE TABLE IF NOT EXISTS "commands_fts_idx" (
	"segid"	,
	"term"	,
	"pgno"	,
	PRIMARY KEY("segid","term")
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "commands_fts_content" (
	"id"	INTEGER,
	"c0"	,
	"c1"	,
	"c2"	,
	"c3"	,
	PRIMARY KEY("id")
);
CREATE TABLE IF NOT EXISTS "commands_fts_docsize" (
	"id"	INTEGER,
	"sz"	BLOB,
	PRIMARY KEY("id")
);
CREATE TABLE IF NOT EXISTS "commands_fts_config" (
	"k"	,
	"v"	,
	PRIMARY KEY("k")
) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "commands" (
	"id"	INTEGER NOT NULL,
	"name"	TEXT NOT NULL UNIQUE,
	"description"	TEXT,
	"usage_command"	TEXT,
	"fallback_usage"	TEXT,
	"location"	TEXT,
	"type"	TEXT,
	"language"	TEXT,
	"source_url"	TEXT,
	"source_repo_url"	TEXT,
	PRIMARY KEY("id" AUTOINCREMENT)
);
INSERT INTO "commands_fts_data" ("id","block") VALUES (1,'');
INSERT INTO "commands_fts_data" ("id","block") VALUES (10,X'00000000000000');
INSERT INTO "commands_fts_config" ("k","v") VALUES ('version',4);
CREATE TRIGGER commands_fts_ai
  AFTER INSERT ON commands BEGIN
  INSERT INTO commands_fts
  (id, name, description, language)
  VALUES (NEW.id, NEW.name, NEW.description, NEW.language);
END;
CREATE TRIGGER commands_fts_ad
  AFTER DELETE ON commands BEGIN
  INSERT INTO commands_fts
  (commands_fts, id, name, description, language)
  VALUES
  ('delete', OLD.id, OLD.name, OLD.description, OLD.language);
END;

---
-- CREATE TRIGGER [{table}_au]
--	 AFTER UPDATE ON [{table}] BEGIN
                  -- INSERT INTO [{table}_fts]
									-- ([{table}_fts], rowid, {columns})
									--VALUES('delete', old.rowid, {old_cols});
                  INSERT INTO [{table}_fts] (rowid, {columns})
									VALUES (new.rowid, {new_cols});
                END;
---
CREATE TRIGGER commands_fts_au
  AFTER UPDATE ON commands BEGIN
  INSERT INTO commands_fts
		(commands_fts, id, name, description, language)
		VALUES
		('delete', OLD.id, OLD.name, OLD.description, OLD.language);
  INSERT INTO commands_fts
		(id, name, description, language)
		VALUES
		(NEW.id, NEW.name, NEW.description, NEW.language);
END;
COMMIT;
