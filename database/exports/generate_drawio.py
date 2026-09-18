"""Generate an editable diagrams.net ERD from PCForge V1 (Python 3, no packages).

This parser targets the CREATE TABLE ... ENGINE=InnoDB syntax in V1.
It does not apply later ALTER migrations or connect to a running database.
"""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / 'backend/src/main/resources/db/migration/V1__schema.sql'
OUTPUT = HERE / 'PCForge_ERD.drawio'
COLORS = ['#dae8fc', '#d5e8d4', '#fff2cc', '#f8cecc', '#e1d5e7',
          '#ffe6cc', '#d0cee2', '#b1ddf0', '#fad9d5', '#cce5ff', '#e6e6e6']


def split_sql(text):
    """Split commas outside parentheses and SQL strings."""
    parts, start, depth, quote = [], 0, 0, None
    i = 0
    while i < len(text):
        char = text[i]
        if quote:
            if char == '\\':
                i += 1
            elif char == quote:
                if i + 1 < len(text) and text[i + 1] == quote:
                    i += 1
                else:
                    quote = None
        elif char in "'\"`":
            quote = char
        elif char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
        elif char == ',' and depth == 0:
            parts.append(text[start:i].strip())
            start = i + 1
        i += 1
    parts.append(text[start:].strip())
    return parts


def names(text):
    return [x.strip().strip('`') for x in text.split(',')]


def parse(sql):
    sections = list(re.finditer(r'^-- (\d{2})\. (.+)$', sql, re.M))
    tables = {}
    for match in re.finditer(r'CREATE TABLE (\w+)\s*\((.*?)\)\s*ENGINE=InnoDB;', sql, re.S):
        name, body = match.groups()
        section = next(s for s in reversed(sections) if s.start() < match.start())
        table = dict(name=name, group=int(section[1]), title=section[2], columns=[], pk=[], unique=[], fk=[], ddl=match[0])
        for item in split_sql(re.sub(r'--[^\n]*', '', body)):
            fk = re.search(r'FOREIGN KEY\s*\(([^)]+)\)\s*REFERENCES\s+(\w+)\s*\(([^)]+)\)', item)
            pk = re.match(r'PRIMARY KEY\s*\(([^)]+)\)', item)
            uk = re.match(r'UNIQUE KEY\s+\w+\s*\(([^)]+)\)', item)
            if fk:
                table['fk'].append((names(fk[1]), fk[2], names(fk[3])))
            elif pk:
                table['pk'] = names(pk[1])
            elif uk:
                table['unique'].append(names(uk[1]))
            elif re.match(r'(CONSTRAINT|CHECK|KEY|FULLTEXT)\b', item):
                continue
            else:
                column = re.match(r'(\w+)\s+(\w+(?:\([^)]*\))?)(.*)', item, re.S)
                if not column:
                    raise ValueError(f'Unsupported column in {name}: {item}')
                cname, dtype, rest = column.groups()
                table['columns'].append(dict(name=cname, type=dtype,
                    required='NOT NULL' in rest or 'PRIMARY KEY' in rest,
                    generated='GENERATED ALWAYS' in rest, auto='AUTO_INCREMENT' in rest))
                if 'PRIMARY KEY' in rest:
                    table['pk'].append(cname)
                if re.search(r'\bUNIQUE\b', rest):
                    table['unique'].append([cname])
        tables[name] = table
    assert len(tables) == len(re.findall(r'CREATE TABLE\b', sql))
    assert sum(len(t['fk']) for t in tables.values()) == len(re.findall(r'FOREIGN KEY\b', sql))
    for table in tables.values():
        cols = {c['name'] for c in table['columns']}
        assert set(table['pk']) <= cols
        for local, parent, remote in table['fk']:
            assert set(local) <= cols and len(local) == len(remote)
            assert set(remote) <= {c['name'] for c in tables[parent]['columns']}
    return tables


def cell(root, cid, value, style, x, y, w, h, parent='1'):
    node = ET.SubElement(root, 'mxCell', id=cid, value=value, style=style, vertex='1', parent=parent)
    ET.SubElement(node, 'mxGeometry', x=str(x), y=str(y), width=str(w), height=str(h), **{'as': 'geometry'})
    return node


def page(document, pid, title):
    diagram = ET.SubElement(document, 'diagram', id=pid, name=title)
    model = ET.SubElement(diagram, 'mxGraphModel', dx='1400', dy='900', grid='1', gridSize='10',
                          guides='1', tooltips='1', connect='1', arrows='1', fold='1', page='0', math='0', shadow='0')
    root = ET.SubElement(model, 'root')
    ET.SubElement(root, 'mxCell', id='0')
    ET.SubElement(root, 'mxCell', id='1', parent='0')
    cell(root, 'heading', title, 'text;html=0;align=left;fontSize=24;fontStyle=1;', 40, 20, 2200, 40)
    cell(root, 'legend', 'PK: primary key | FK: foreign key | UK: member of a unique key (may be composite) | NN: NOT NULL | AI: auto increment | GEN: generated\nParent -> child: 1 or 0..1 at parent; 0..N or 0..1 at child. Gray tables: references from another module. SQL constraints: hover over table.',
         'text;html=0;align=left;whiteSpace=wrap;fontSize=12;', 40, 65, 2400, 55)
    return root


def add_table(root, table, x, y, external=False):
    name = table['name']
    color = '#f5f5f5' if external else COLORS[(table['group'] - 1) % len(COLORS)]
    height = 34 + 23 * len(table['columns'])
    node = cell(root, name, name + (' [REF]' if external else ''),
        f'swimlane;html=0;startSize=34;horizontal=1;rounded=0;collapsible=0;fontStyle=1;fontSize=14;fillColor={color};swimlaneFillColor=#ffffff;strokeColor=#666666;align=left;spacingLeft=10;',
        x, y, 560, height)
    # User objects provide draw.io tooltips and retain the original DDL.
    root.remove(node)
    obj = ET.SubElement(root, 'object', id=name, label=node.get('value'), tooltip=table['ddl'])
    del node.attrib['id']
    del node.attrib['value']
    obj.append(node)
    foreign = {c for fk in table['fk'] for c in fk[0]}
    unique = {c for key in table['unique'] for c in key}
    for i, col in enumerate(table['columns']):
        cname = col['name']
        tags = [tag for tag, yes in [('PK', cname in table['pk']), ('FK', cname in foreign), ('UK', cname in unique)] if yes]
        flags = [tag for tag, yes in [('NN', col['required']), ('AI', col['auto']), ('GEN', col['generated'])] if yes]
        value = f"{'/'.join(tags) or '-':10} {cname} : {col['type']}  {' '.join(flags)}"
        cell(root, f'{name}.{cname}', value,
             'text;html=0;align=left;verticalAlign=middle;spacingLeft=8;fontFamily=Consolas;fontSize=11;overflow=hidden;' + ('fontStyle=1;' if tags else ''),
             0, 34 + i * 23, 560, 23, parent=name)
    return height


def edge(root, eid, source, target, label, style):
    node = ET.SubElement(root, 'mxCell', id=eid, value=label, edge='1', parent='1', source=source, target=target,
        style='edgeStyle=orthogonalEdgeStyle;rounded=0;html=0;fontSize=10;labelBackgroundColor=#ffffff;strokeColor=#777777;' + style)
    ET.SubElement(node, 'mxGeometry', relative='1', **{'as': 'geometry'})


def erd_page(document, pid, title, tables, selected):
    root = page(document, pid, title)
    local = set(selected)
    external = sorted({fk[1] for name in selected for fk in tables[name]['fk']} - local)
    heights = [150] * 4
    for name in list(selected) + external:
        lane = min(range(4), key=lambda i: heights[i])
        height = add_table(root, tables[name], 40 + lane * 750, heights[lane], name not in local)
        heights[lane] += height + 120
    count = 0
    for name in selected:
        table = tables[name]
        for cols, parent, refs in table['fk']:
            required = all(c['required'] for c in table['columns'] if c['name'] in cols)
            single = any(set(key) <= set(cols) for key in [table['pk']] + table['unique'] if key)
            # Source is referenced parent; target is referencing child.
            parent_marker = 'ERmandOne' if required else 'ERzeroToOne'
            child_marker = 'ERzeroToOne' if single else 'ERzeroToMany'
            label = f"({', '.join(refs)}) -> ({', '.join(cols)})"
            edge(root, f'fk-{count}', f'{parent}.{refs[0]}', f'{name}.{cols[0]}', label,
                 f'startArrow={parent_marker};endArrow={child_marker};startSize=14;endSize=14;')
            count += 1
    return count


def main():
    sql = SOURCE.read_text(encoding='utf-8-sig')
    tables = parse(sql)
    document = ET.Element('mxfile', host='app.diagrams.net', agent='PCForge ERD generator', version='24.7.17', type='device')
    total_fk = erd_page(document, 'all', '00 - Full ERD', tables, list(tables))
    for group in sorted({t['group'] for t in tables.values()}):
        selected = [n for n, t in tables.items() if t['group'] == group]
        title = f'{group:02d} - {tables[selected[0]]["title"]}'
        erd_page(document, f'module-{group}', title, tables, selected)
    root = page(document, 'views', '12 - Reporting views (dashed arrows = SQL dependencies)')
    views = list(re.finditer(r'CREATE VIEW (\w+) AS\s*(.*?);', sql, re.S))
    deps = {}
    for i, view in enumerate(views):
        name, query = view.groups()
        dependencies = sorted(set(re.findall(r'\b(?:FROM|JOIN)\s+(\w+)', query, re.I)) & tables.keys())
        deps[name] = dependencies
        height = 65 + 17 * len(query.splitlines())
        cell(root, name, name + '\n\n' + query,
             'rounded=0;html=0;whiteSpace=wrap;align=left;verticalAlign=top;spacing=10;fontFamily=Consolas;fontSize=11;fillColor=#fff2cc;strokeColor=#d6b656;',
             800, 150 + i * 650, 1100, height)
    for i, name in enumerate(sorted({n for d in deps.values() for n in d})):
        cell(root, name, name, 'rounded=1;html=0;fillColor=#dae8fc;fontSize=14;', 40, 150 + i * 260, 450, 60)
    for view, dependencies in deps.items():
        for name in dependencies:
            edge(root, f'dep-{view}-{name}', name, view, 'reads from', 'dashed=1;endArrow=open;')
    ET.indent(document, space='  ')
    ET.ElementTree(document).write(OUTPUT, encoding='utf-8', xml_declaration=True)
    # Check serialized XML, cell references and full-page table/column/FK coverage.
    loaded = ET.parse(OUTPUT).getroot()
    for diagram in loaded.findall('diagram'):
        graph = diagram.find('mxGraphModel/root')
        ids = [node.get('id') for node in graph.iter() if node.get('id') is not None]
        assert len(ids) == len(set(ids)), diagram.get('name')
        for node in graph.iter('mxCell'):
            for attr in ('source', 'target', 'parent'):
                if node.get(attr):
                    assert node.get(attr) in ids, (diagram.get('name'), node.attrib)
    full = loaded.find('diagram/mxGraphModel/root')
    assert len(full.findall('object')) == len(tables)
    assert len(full.findall("mxCell[@edge='1']")) == total_fk
    columns = sum(len(t['columns']) for t in tables.values())
    assert sum(len(full.findall(f"mxCell[@parent='{name}']")) for name in tables) == columns
    print(f'Created {OUTPUT}')
    print(f'Validated: {len(tables)} tables, {columns} columns, {total_fk} foreign keys, {len(views)} views, {len(loaded.findall("diagram"))} pages.')


if __name__ == '__main__':
    main()
