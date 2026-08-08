import os
import oracledb
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env", override=True)

ORACLE_USER = os.getenv("ORACLE_USER")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD")
ORACLE_DSN = os.getenv("ORACLE_DSN")
ORACLE_WALLET = os.getenv("ORACLE_WALLET")
ORACLE_WALLET_PASSWORD = os.getenv("ORACLE_WALLET_PASSWORD")


def get_connection():
    return oracledb.connect(
        user=ORACLE_USER,
        password=ORACLE_PASSWORD,
        dsn=ORACLE_DSN,
        config_dir=ORACLE_WALLET,
        wallet_location=ORACLE_WALLET,
        wallet_password=ORACLE_WALLET_PASSWORD
    )


def fetch_all(sql, params=None):
    connection = get_connection()
    cursor = connection.cursor()

    try:
        cursor.execute(sql, params or {})

        columns = [column[0].lower() for column in cursor.description]

        return [
            dict(zip(columns, row))
            for row in cursor.fetchall()
        ]

    finally:
        cursor.close()
        connection.close()


def fetch_one(sql, params=None):
    connection = get_connection()
    cursor = connection.cursor()

    try:
        cursor.execute(sql, params or {})

        row = cursor.fetchone()

        if row is None:
            return None

        columns = [column[0].lower() for column in cursor.description]

        return dict(zip(columns, row))

    finally:
        cursor.close()
        connection.close()


def execute(sql, params=None):
    connection = get_connection()
    cursor = connection.cursor()

    try:
        cursor.execute(sql, params or {})
        connection.commit()

    except Exception:
        connection.rollback()
        raise

    finally:
        cursor.close()
        connection.close()


def test_connection():
    connection = get_connection()
    cursor = connection.cursor()

    try:
        cursor.execute("""
            SELECT
                USER AS usuario,
                SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS servicio
            FROM DUAL
        """)

        row = cursor.fetchone()

        return {
            "user": row[0],
            "service": row[1]
        }

    finally:
        cursor.close()
        connection.close()