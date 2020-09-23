import re
import asyncio
import logging
from itertools import chain
import aiohttp

from bs4 import BeautifulSoup

from util import add_column_if_absent

log = logging.getLogger(__name__)

_ceq_columns = [
    'url',
    'pass_share',
    'answers',
    'overall_score',
    'important',
    'good_teaching',
    'clear_goals',
    'assessment',
    'workload'
]


async def _ceq_get_query(code, year, sp):
    semester = 'HT'
    if sp > 2:
        semester = 'VT'
        sp -= 2

    url = f'http://www.ceq.lth.se/rapporter/{year}_{semester}/LP{sp}/{code}_{year}_{semester}_LP{sp}_slutrapport_en.html'
    #log.debug(f'requesting url: {url}')
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            return resp.status, await resp.read(), str(resp.url)


async def _get_latest_ceq(code, sp, oldcoursecode=None):
    allsp = chain([sp], set(range(1, 5)) - {sp})
    for testsp in allsp:
        for year in range(2020, 2014, -1):
            status, resp, url = await _ceq_get_query(code, year, testsp)
            if status == 200:
                soup = BeautifulSoup(resp, 'html.parser')
                return soup, url

    # LTH changed course codes recently, so some courses have no ceq reports yet.
    # If we don't find a ceq report we try to fetch an old one.
    if oldcoursecode and code in oldcoursecode:
        return await _get_latest_ceq(oldcoursecode[code], sp)

    return None, None


def _update_courses(coursedict, columns, cursor):
    values = list((*v, k) for k, v in coursedict.items())
    sql = f"UPDATE courses SET {', '.join(col + ' = ?' for col in columns)} WHERE course_code = ?"
    cursor.executemany(sql, values)


def ceq(conn):
    def tablevalue(soup):
        return lambda rowname: soup.find(string=rowname).parent.find_next_sibling('td').string

    total_ratio = re.compile(r'(\d+)\s*/\s*(\d+)\s*%')

    def total_ratio_field(return_total=True):
        def getvalue(field):
            total, ratio = [v for v in total_ratio.match(field).groups()]
            return total if return_total else ratio
        return getvalue

    # Mapping from new to old course codes.
    oldcoursecodes = dict()
    with open('coursecodes.csv', 'r') as f:
        for l in f:
            old, new = l.strip().split(',')
            oldcoursecodes[new] = old

    ceq_db_names = ['ceq_' + name for name in _ceq_columns]
    c = conn.cursor()
    for col in ceq_db_names:
        add_column_if_absent(c, col, 'INTEGER')

    query = c.execute('SELECT course_code, sp1_lectures, sp2_lectures, sp3_lectures, sp4_lectures FROM courses')
    courses_complete = dict()  # Complete CEQ containing scores
    courses_basic = dict()  # Basic CEQ e.g. containing share of student that passed

    async def process_ceq(code, sp):
        try:
            last, _ = next(filter(lambda x: x[1], enumerate(sp[::-1])))
        except StopIteration:
            log.debug(f'Course {code} lacks sp data')
            return
        data = dict()
        soup, data['url'] = await _get_latest_ceq(code, 4 - last, oldcoursecodes)
        if soup:
            getvalue = tablevalue(soup)

            passed = getvalue(re.compile('Number and share of passed students.*'))
            try:
                passRate = min(100, int(total_ratio_field(False)(passed))) # 122% pass rate ftw: https://www.ceq.lth.se/rapporter/2019_HT/LP2/VBEN15_2019_HT_LP2_slutrapport_en.html
            except:
                log.error(passed)
                log.error('unknown PassShare. {}'.format(data['url']))
                passRate = 0 # Should be None.
            data['pass_share'] = passRate

            try:
                answer_field = getvalue('Number answers and response rate')
                data['answers'] = int(total_ratio_field(True)(answer_field))
                data['overall_score'] = int(getvalue('Overall, I am satisfied with this course'))
                data['important'] = int(getvalue('The course seems important for my education'))
                data['good_teaching'] = int(getvalue('Good Teaching'))
                data['clear_goals'] = int(getvalue('Clear Goals and Standards'))
                data['assessment'] = int(getvalue('Appropriate Assessment'))
                data['workload'] = int(getvalue('Appropriate Workload'))
                return code, [data[key] for key in _ceq_columns]
            except AttributeError:
                return code, [data[key] for key in _ceq_columns[:2]]
            except TypeError:
                return code, [data[key] for key in _ceq_columns[:2]]
        else:
            log.debug(f'No CEQ found for {code} SP{last}')

    loop = asyncio.get_event_loop()

    ceq_tasks = [process_ceq(code, sp) for code, *sp in query]
    chunk_size = 50
    task_groups = [ceq_tasks[i:i + chunk_size] for i in range(0, len(ceq_tasks), chunk_size)]
    for group in task_groups:
        getall = asyncio.gather(*group)
        loop.run_until_complete(getall)
        for code, ceq_data in filter(None, getall.result()):
            if len(ceq_data) == len(_ceq_columns):
                courses_complete[code] = ceq_data
            else:
                courses_basic[code] = ceq_data

    log.info(f'No. courses with a complete CEQ: {len(courses_complete)}')
    log.info(f'No. courses with a basic CEQ: {len(courses_basic)}')
    _update_courses(courses_complete, ceq_db_names, c)
    _update_courses(courses_basic, ceq_db_names[0:2], c)

    conn.commit()
