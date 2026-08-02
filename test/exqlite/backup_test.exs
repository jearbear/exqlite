defmodule Exqlite.BackupTest do
  use ExUnit.Case

  alias Exqlite.Sqlite3

  defp seed(conn) do
    :ok = Sqlite3.execute(conn, "CREATE TABLE t(a INTEGER, b TEXT)")
    :ok = Sqlite3.execute(conn, "INSERT INTO t VALUES (1,'one'),(2,'two'),(3,'three')")
  end

  defp count(conn) do
    {:ok, stmt} = Sqlite3.prepare(conn, "SELECT count(*) FROM t")
    {:ok, [[count]]} = Sqlite3.fetch_all(conn, stmt)
    :ok = Sqlite3.release(conn, stmt)
    count
  end

  describe ".backup_init/4" do
    test "returns a backup handle" do
      {:ok, source} = Sqlite3.open(":memory:")
      seed(source)
      {:ok, dest} = Sqlite3.open(":memory:")

      assert {:ok, backup} = Sqlite3.backup_init(dest, "main", source, "main")
      assert is_reference(backup)
      assert :ok = Sqlite3.backup_finish(backup)
    end

    test "errors with an invalid connection" do
      {:ok, source} = Sqlite3.open(":memory:")

      assert {:error, :invalid_connection} =
               Sqlite3.backup_init(make_ref(), "main", source, "main")
    end
  end

  describe ".backup_step/2" do
    test "copies all pages with a single negative step" do
      {:ok, source} = Sqlite3.open(":memory:")
      seed(source)
      {:ok, dest} = Sqlite3.open(":memory:")

      {:ok, backup} = Sqlite3.backup_init(dest, "main", source, "main")
      assert :done = Sqlite3.backup_step(backup, -1)
      assert :ok = Sqlite3.backup_finish(backup)

      assert count(dest) == 3
    end

    test "copies pages incrementally" do
      {:ok, source} = Sqlite3.open(":memory:")
      seed(source)
      {:ok, dest} = Sqlite3.open(":memory:")

      {:ok, backup} = Sqlite3.backup_init(dest, "main", source, "main")

      assert :done = step_until_done(backup)
      assert :ok = Sqlite3.backup_finish(backup)

      assert count(dest) == 3
    end

    test "returns an error after the backup has been finished" do
      {:ok, source} = Sqlite3.open(":memory:")
      seed(source)
      {:ok, dest} = Sqlite3.open(":memory:")

      {:ok, backup} = Sqlite3.backup_init(dest, "main", source, "main")
      assert :ok = Sqlite3.backup_finish(backup)
      assert {:error, :invalid_backup} = Sqlite3.backup_step(backup, 1)
    end
  end

  describe ".backup_finish/1" do
    test "is idempotent" do
      {:ok, source} = Sqlite3.open(":memory:")
      seed(source)
      {:ok, dest} = Sqlite3.open(":memory:")

      {:ok, backup} = Sqlite3.backup_init(dest, "main", source, "main")
      assert :done = Sqlite3.backup_step(backup, -1)
      assert :ok = Sqlite3.backup_finish(backup)
      assert :ok = Sqlite3.backup_finish(backup)
    end
  end

  defp step_until_done(backup) do
    case Sqlite3.backup_step(backup, 1) do
      :ok -> step_until_done(backup)
      other -> other
    end
  end
end
