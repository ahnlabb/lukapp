def table_info(cursor):
    query = cursor.execute('PRAGMA table_info(courses)')
    _, name, affinity, _, _, _ = map(list, zip(*query))
    return name, affinity


def add_column_if_absent(cursor, colname, affinity):
    names, affinities = table_info(cursor)
    if colname not in names:
        cursor.execute(f'ALTER TABLE courses ADD COLUMN {colname} {affinity}')
