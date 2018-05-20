import sqlite3
import logging
import json

log = logging.getLogger(__name__)


def elmstr(x):
    if type(x) is str:
        return '"{}"'.format(x)
    else:
        return str(x)


def coursestr(c):
    return 'Course ' + ' '.join(map(elmstr, c))


if __name__ == '__main__':
    conn = sqlite3.connect('../lot.db')
    c = conn.cursor()
    query = c.execute('SELECT course_code, credits, IFNULL(cycle,0), course_name, IFNULL(ceq_pass_share,-1), IFNULL(ceq_overall_score,-1), IFNULL(ceq_important,-1) FROM courses')
    with open('TableData.elm', 'w') as out:
        with open('TableData.template.elm', 'r') as f:
            out.write(f.read())
        out.write('    ([')
        try:
            while True:
                out.write(coursestr(next(query)) + '\n')
                for _ in range(19):
                    out.write('    ,' + coursestr(next(query)) + '\n')
                out.write('    ] ++ [')
        except StopIteration:
            out.write('    ])')
