# frozen_string_literal: true

# The history of uploaded transfers files. There is one row for every line
# of every file, whether that transfer completed or was rejected.
Sequel.migration do
  change do
    create_table(:transfers) do
      primary_key :id

      # Which file the line came from, and when that file was uploaded.
      # Every line of one file carries the same two values. The fingerprint
      # is a SHA-256 hash of the file, which is always 64 characters.
      String :fingerprint, size: 64, null: false, index: true
      column :uploaded_at, :timestamptz, null: false

      # The line as it appeared in the file. These are kept as text, and may
      # be empty, because a rejected line can contain anything.
      Integer :line, null: false
      String :from_account, text: true
      String :to_account, text: true
      String :amount, text: true

      # Empty when the transfer completed.
      String :rejection_reason, text: true
    end
  end
end
