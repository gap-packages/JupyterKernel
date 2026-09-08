import { StreamLanguage, StringStream } from '@codemirror/language';

const KEYWORDS = new Set([
  'and',
  'atomic',
  'break',
  'continue',
  'do',
  'elif',
  'else',
  'end',
  'fi',
  'for',
  'function',
  'if',
  'in',
  'local',
  'mod',
  'not',
  'od',
  'or',
  'quit',
  'QUIT',
  'readonly',
  'readwrite',
  'rec',
  'repeat',
  'return',
  'then',
  'until',
  'while'
]);

const ATOMS = new Set(['true', 'false', 'fail', 'infinity']);

interface GapState {
  inString: false | '"' | "'";
}

function tokenString(quote: '"' | "'", stream: StringStream, state: GapState): string {
  while (!stream.eol()) {
    const ch = stream.next();
    if (ch === '\\' && !stream.eol()) {
      stream.next();
      continue;
    }
    if (ch === quote) {
      state.inString = false;
      return 'string';
    }
  }
  return 'string';
}

export const gapStreamParser = {
  name: 'gap',

  startState(): GapState {
    return { inString: false };
  },

  token(stream: StringStream, state: GapState): string | null {
    if (state.inString) {
      return tokenString(state.inString, stream, state);
    }

    if (stream.eatSpace()) {
      return null;
    }

    const ch = stream.peek();
    if (ch === undefined) {
      return null;
    }

    if (ch === '#') {
      stream.skipToEnd();
      return 'comment';
    }

    if (ch === '"' || ch === "'") {
      stream.next();
      state.inString = ch as '"' | "'";
      return tokenString(ch as '"' | "'", stream, state);
    }

    if (/[0-9]/.test(ch)) {
      stream.eatWhile(/[0-9]/);
      if (stream.eat('.')) {
        stream.eatWhile(/[0-9]/);
      }
      if (stream.eat(/[eE]/)) {
        stream.eat(/[+-]/);
        stream.eatWhile(/[0-9]/);
      }
      return 'number';
    }

    if (/[A-Za-z_]/.test(ch)) {
      stream.eatWhile(/[A-Za-z0-9_]/);
      const word = stream.current();
      if (KEYWORDS.has(word)) {
        return 'keyword';
      }
      if (ATOMS.has(word)) {
        return 'atom';
      }
      return 'variableName';
    }

    if (stream.match(':=') || stream.match('->') || stream.match('..') ||
        stream.match('<=') || stream.match('>=') || stream.match('<>')) {
      return 'operator';
    }

    if ('+-*/^=<>'.indexOf(ch) >= 0) {
      stream.next();
      return 'operator';
    }

    stream.next();
    return null;
  },

  languageData: {
    commentTokens: { line: '#' },
    closeBrackets: { brackets: ['(', '[', '{', '"', "'"] },
    indentOnInput: /^\s*(?:end|fi|od|until|else|elif)\b/
  }
};

export const gapLanguage = StreamLanguage.define(gapStreamParser);
