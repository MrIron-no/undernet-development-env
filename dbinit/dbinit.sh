#!/bin/bash

export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
psql=( psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password )

for db in local_db ccontrol chanfix dronescan; do
  "${psql[@]}" --dbname postgres --set db="$db" <<-'EOSQL'
				CREATE DATABASE :"db";
			EOSQL
  echo
done

echo "$0: Setting up cservice db"
for sql_file in cservice.sql cservice.languages.sql cservice.translations.sql cservice.help.sql cservice.config.sql cservice.addme.sql; do
  ${psql[@]} --dbname cservice < /gnuworld/doc/${sql_file}
done

# Allow Admin (user_id 1) to authenticate from this Compose network.
# Host clients published via leaf/hub appear as the bridge gateway (10.5.0.1);
# IPR_DEFAULT_REJECT rejects * access with no matching ip_restrict rows.
echo "$0: Adding Admin IPR for Docker network 10.5.0.0/16"
${psql[@]} --dbname cservice <<-'EOSQL'
	INSERT INTO ip_restrict (user_id, added_by, added, type, expiry, value, description)
	VALUES (
		1,
		1,
		EXTRACT(EPOCH FROM NOW())::int,
		1,
		0,
		'10.5.0.0/16',
		'undernet-development-env docker network'
	);
EOSQL

echo "$0: Setting up ccontrol db"
for sql_file in ccontrol.sql ccontrol.help.sql ccontrol.addme.sql ccontrol.commands.sql; do
  ${psql[@]} --dbname ccontrol < /gnuworld/doc/${sql_file}
done

echo "$0: Setting up chanfix db"
for sql_file in chanfix.sql chanfix.languages.sql chanfix.language.english.sql chanfix.help.sql chanfix.addme.sql; do
  ${psql[@]} --dbname chanfix < /gnuworld/mod.openchanfix/doc/${sql_file}
done

echo "$0: Setting up dronescan db"
${psql[@]} --dbname dronescan < /gnuworld/doc/dronescan.sql

echo "$0: Setting up local db"
${psql[@]} --dbname local_db < /gnuworld/doc/cservice.web.sql

theme_dir=/cservice-web/docs/gnuworld/themes/data
if [ -d "$theme_dir" ]; then
  echo "$0: Loading themes into local_db..."
  for theme in $(find "$theme_dir" -name "*.sql"); do
    cat "$theme" | ${psql[@]} --dbname local_db
  done
else
  echo "$0: Skipping themes (cservice-web not mounted or missing $theme_dir)"
fi

# Create initialization completion marker
echo "$0: Creating initialization completion marker..."
${psql[@]} --dbname cservice <<-'EOSQL'
	CREATE TABLE IF NOT EXISTS init_completed (completed_at TIMESTAMP DEFAULT NOW());
	INSERT INTO init_completed VALUES (NOW());
EOSQL
echo "$0: Database initialization complete!"
