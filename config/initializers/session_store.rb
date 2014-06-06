# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_pepfar_reports_session',
  :secret      => '9773e8502f5f163da1ec3e99545b14b74cff4de2c6567253a3b02128eb4934d1164bbf8eb699075a534bb9359e0a26472141cc1cb63e1de96a01390e019b332f'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
