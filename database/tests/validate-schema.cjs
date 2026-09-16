// Optional static validation: node validate-schema.cjs /path/to/node-sql-parser
// Reads files only. A third-party parser is NOT a MySQL server execution test.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Parser } = require(process.argv[2] || 'node-sql-parser');
const parser = new Parser();
const root = path.resolve(__dirname, '../..');
const migrationDir = 'backend/src/main/resources/db/migration';
const schema = fs.readFileSync(path.join(root, migrationDir, 'V1__schema.sql'), 'utf8');
const tables = new Map();
const names = [...schema.matchAll(/CREATE TABLE\s+(\w+)\s*\(([\s\S]*?)\) ENGINE=InnoDB;/g)];
assert(names.length > 100, 'Expected the complete modular schema');
for (const [, name, body] of names) {
  assert(!tables.has(name), `Duplicate table: ${name}`);
  const columns = new Set([...body.matchAll(/^  (\w+)\s+(?:BIGINT|INT|SMALLINT|VARCHAR|CHAR|BINARY|BOOLEAN|DATETIME|DECIMAL|TEXT|LONGTEXT|JSON)\b/gm)].map(m => m[1]));
  for (const fk of body.matchAll(/FOREIGN KEY\s*\(([^)]+)\) REFERENCES (\w+)\(([^)]+)\)/g)) {
    const local = fk[1].split(',').map(x => x.trim());
    const target = fk[2] === name ? columns : tables.get(fk[2]);
    assert(target, `${name}: referenced table ${fk[2]} must already exist`);
    const remote = fk[3].split(',').map(x => x.trim());
    assert.equal(local.length, remote.length, `${name}: mismatched FK arity`);
    local.forEach(c => assert(columns.has(c), `${name}: missing local FK column ${c}`));
    remote.forEach(c => assert(target.has(c), `${name}: missing remote FK column ${fk[2]}.${c}`));
  }
  tables.set(name, columns);
}
let parsed = 0;
let recognizedNativeStatements = 0;
const unsupported = [];
function splitStatements(source) {
  const result = [];
  let current = '';
  let quote = null;
  let lineComment = false;
  let blockComment = false;
  for (let i = 0; i < source.length; i++) {
    const ch = source[i];
    const next = source[i + 1];
    if (lineComment) {
      if (ch === '\n') { lineComment = false; current += '\n'; }
      continue;
    }
    if (blockComment) {
      if (ch === '*' && next === '/') { blockComment = false; current += ' '; i++; }
      continue;
    }
    if (quote) {
      current += ch;
      if (ch === '\\') { current += source[++i] || ''; continue; }
      if (ch === quote) {
        if (next === quote) { current += next; i++; }
        else quote = null;
      }
      continue;
    }
    if ((ch === '-' && next === '-' && /\s/.test(source[i + 2] || ' ')) || ch === '#') {
      lineComment = true; current += ' '; continue;
    }
    if (ch === '/' && next === '*') { blockComment = true; i++; continue; }
    if (ch === "'" || ch === '"' || ch === '`') { quote = ch; current += ch; continue; }
    if (ch === ';') {
      if (current.trim()) result.push(current.trim());
      current = '';
    } else current += ch;
  }
  assert(!quote && !blockComment, 'Unclosed SQL quote/comment');
  if (current.trim()) result.push(current.trim());
  return result;
}
for (const file of ['database/bootstrap/bootstrap.sql', `${migrationDir}/V1__schema.sql`, `${migrationDir}/V2__reference_data.sql`, 'database/examples/promotion_examples.sql']) {
  const source = fs.readFileSync(path.join(root, file), 'utf8');
  const statements = splitStatements(source);
  for (const [index, sql] of statements.entries()) {
    // node-sql-parser does not implement native MySQL SET NAMES grammar.
    if (/^SET NAMES utf8mb4$/i.test(sql)) { recognizedNativeStatements++; continue; }
    try {
      parser.astify(sql, { database: 'MySQL' });
      parsed++;
    } catch (error) {
      unsupported.push({ file, statement: index + 1, start: sql.slice(0, 100), error: error.message });
    }
  }
}
console.log(JSON.stringify({ tables: tables.size, views: (schema.match(/CREATE VIEW /g) || []).length, foreignKeys: (schema.match(/FOREIGN KEY /g) || []).length, parsedStatements: parsed, recognizedNativeStatements, parserFailures: unsupported }, null, 2));
if (unsupported.length) process.exitCode = 1;
