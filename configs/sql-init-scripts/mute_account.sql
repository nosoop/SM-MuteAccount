
CREATE TABLE mutelist (
	account INTEGER,
	end_time INTEGER,
	reason varchar(256),
	admin_account INTEGER
);

-- optimize account lookups
CREATE INDEX account_mutes ON mutelist (account);
