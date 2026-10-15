import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { RecordItem, DayMark, MonthSummary, DaySummary, PlaceStat, MonthHighlight, RecType, BackupRecord } from './Types';

const STORE_NAME: string = 'diary.db';

const SQL_CREATE_RECORDS: string = 'CREATE TABLE IF NOT EXISTS records (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
  'date TEXT NOT NULL, ' +
  'type INTEGER NOT NULL, ' +
  'content TEXT NOT NULL DEFAULT \'\', ' +
  'amount REAL NOT NULL DEFAULT 0, ' +
  'created_at INTEGER NOT NULL DEFAULT 0)';

const SQL_CREATE_SETTINGS: string = 'CREATE TABLE IF NOT EXISTS settings (' +
  'key TEXT PRIMARY KEY, ' +
  'value TEXT NOT NULL DEFAULT \'\')';

// 单机数据库：所有数据仅保存在手机本地
export class Db {
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<void> | null = null;

  static init(context: common.Context): Promise<void> {
    if (Db.initPromise !== null) {
      return Db.initPromise;
    }
    const config: relationalStore.StoreConfig = {
      name: STORE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    Db.initPromise = relationalStore.getRdbStore(context, config).then(async (store: relationalStore.RdbStore) => {
      Db.store = store;
      await store.executeSql(SQL_CREATE_RECORDS);
      await store.executeSql(SQL_CREATE_SETTINGS);
    });
    return Db.initPromise;
  }

  private static async getStore(): Promise<relationalStore.RdbStore> {
    if (Db.initPromise === null) {
      throw new Error('Db not initialized');
    }
    await Db.initPromise;
    return Db.store as relationalStore.RdbStore;
  }

  static async insertRecord(item: RecordItem, createdAt: number = 0): Promise<void> {
    const store = await Db.getStore();
    const vb: relationalStore.ValuesBucket = {
      'date': item.date,
      'type': item.type,
      'content': item.content,
      'amount': item.amount,
      'created_at': createdAt > 0 ? createdAt : Date.now()
    };
    await store.insert('records', vb);
  }

  static async deleteRecord(id: number): Promise<void> {
    const store = await Db.getStore();
    const pred = new relationalStore.RdbPredicates('records');
    pred.equalTo('id', id);
    await store.delete(pred);
  }

  // 编辑收支持录
  static async updateRecord(id: number, item: RecordItem): Promise<void> {
    const store = await Db.getStore();
    const pred = new relationalStore.RdbPredicates('records');
    pred.equalTo('id', id);
    const vb: relationalStore.ValuesBucket = {
      'type': item.type,
      'content': item.content,
      'amount': item.amount
    };
    await store.update(vb, pred);
  }

  static rowToItem(rs: relationalStore.ResultSet): RecordItem {
    const it: RecordItem = {
      id: rs.getLong(rs.getColumnIndex('id')),
      date: rs.getString(rs.getColumnIndex('date')),
      type: rs.getLong(rs.getColumnIndex('type')),
      content: rs.getString(rs.getColumnIndex('content')),
      amount: rs.getDouble(rs.getColumnIndex('amount'))
    };
    return it;
  }

  // 当天全部记录（按时间正序）
  static async getDayRecords(date: string): Promise<Array<RecordItem>> {
    const store = await Db.getStore();
    const pred = new relationalStore.RdbPredicates('records');
    pred.equalTo('date', date).orderByAsc('created_at');
    const rs = await store.query(pred);
    const list: Array<RecordItem> = [];
    while (rs.goToNextRow()) {
      list.push(Db.rowToItem(rs));
    }
    rs.close();
    return list;
  }

  // 当天收支合计
  static async getDaySummary(date: string): Promise<DaySummary> {
    const store = await Db.getStore();
    const sql = 'SELECT ' +
      'COALESCE(SUM(CASE WHEN type = ' + RecType.Expense + ' THEN amount ELSE 0 END), 0) AS exp, ' +
      'COALESCE(SUM(CASE WHEN type = ' + RecType.Income + ' THEN amount ELSE 0 END), 0) AS inc ' +
      'FROM records WHERE date = ?';
    const rs = await store.querySql(sql, [date]);
    const out: DaySummary = { expense: 0, income: 0 };
    if (rs.goToNextRow()) {
      out.expense = rs.getDouble(rs.getColumnIndex('exp'));
      out.income = rs.getDouble(rs.getColumnIndex('inc'));
    }
    rs.close();
    return out;
  }

  // 月历标记：圆点=有事件/行程，金额=支出
  static async getMonthMarks(prefix: string): Promise<Array<DayMark>> {
    const store = await Db.getStore();
    const sql = 'SELECT date, ' +
      'SUM(CASE WHEN type = ' + RecType.Event + ' OR type = ' + RecType.Place + ' THEN 1 ELSE 0 END) AS cnt_ep, ' +
      'SUM(CASE WHEN type = ' + RecType.Expense + ' THEN amount ELSE 0 END) AS exp ' +
      'FROM records WHERE date LIKE ? GROUP BY date';
    const rs = await store.querySql(sql, [prefix + '%']);
    const list: Array<DayMark> = [];
    while (rs.goToNextRow()) {
      const dateStr = rs.getString(rs.getColumnIndex('date'));
      const mk: DayMark = {
        day: Number(dateStr.substring(8)),
        hasEventOrPlace: rs.getLong(rs.getColumnIndex('cnt_ep')) > 0,
        expense: rs.getDouble(rs.getColumnIndex('exp'))
      };
      list.push(mk);
    }
    rs.close();
    return list;
  }

  // 月汇总：记录天数、总支出、总收入
  static async getMonthSummary(prefix: string): Promise<MonthSummary> {
    const store = await Db.getStore();
    const sql = 'SELECT COUNT(DISTINCT date) AS days, ' +
      'COALESCE(SUM(CASE WHEN type = ' + RecType.Expense + ' THEN amount ELSE 0 END), 0) AS exp, ' +
      'COALESCE(SUM(CASE WHEN type = ' + RecType.Income + ' THEN amount ELSE 0 END), 0) AS inc ' +
      'FROM records WHERE date LIKE ?';
    const rs = await store.querySql(sql, [prefix + '%']);
    const out: MonthSummary = { recordDays: 0, expense: 0, income: 0 };
    if (rs.goToNextRow()) {
      out.recordDays = rs.getLong(rs.getColumnIndex('days'));
      out.expense = rs.getDouble(rs.getColumnIndex('exp'));
      out.income = rs.getDouble(rs.getColumnIndex('inc'));
    }
    rs.close();
    return out;
  }

  // 关键词搜索（解决"备忘录难翻找"的核心能力）
  static async search(kw: string): Promise<Array<RecordItem>> {
    const store = await Db.getStore();
    const pred = new relationalStore.RdbPredicates('records');
    pred.like('content', '%' + kw + '%').orderByDesc('date').orderByDesc('created_at').limitAs(100);
    const rs = await store.query(pred);
    const list: Array<RecordItem> = [];
    while (rs.goToNextRow()) {
      list.push(Db.rowToItem(rs));
    }
    rs.close();
    return list;
  }

  // 常去地点排行（当月前5）
  static async getPlaceStats(prefix: string): Promise<Array<PlaceStat>> {
    const store = await Db.getStore();
    const sql = 'SELECT content, COUNT(*) AS c FROM records ' +
      'WHERE type = ' + RecType.Place + ' AND date LIKE ? AND content != \'\' ' +
      'GROUP BY content ORDER BY c DESC LIMIT 5';
    const rs = await store.querySql(sql, [prefix + '%']);
    const list: Array<PlaceStat> = [];
    while (rs.goToNextRow()) {
      const ps: PlaceStat = {
        content: rs.getString(rs.getColumnIndex('content')),
        count: rs.getLong(rs.getColumnIndex('c'))
      };
      list.push(ps);
    }
    rs.close();
    return list;
  }

  // 当月最大一笔花销
  static async getMaxExpense(prefix: string): Promise<MonthHighlight | null> {
    const store = await Db.getStore();
    const sql = 'SELECT content, amount FROM records ' +
      'WHERE type = ' + RecType.Expense + ' AND date LIKE ? ' +
      'ORDER BY amount DESC LIMIT 1';
    const rs = await store.querySql(sql, [prefix + '%']);
    let out: MonthHighlight | null = null;
    if (rs.goToNextRow()) {
      out = { content: rs.getString(rs.getColumnIndex('content')), amount: rs.getDouble(rs.getColumnIndex('amount')) };
    }
    rs.close();
    return out;
  }

  // 备份导出用：全部记录（含 created_at，保持原始顺序）
  static async getAllRaw(): Promise<Array<BackupRecord>> {
    const store = await Db.getStore();
    const pred = new relationalStore.RdbPredicates('records');
    pred.orderByAsc('date').orderByAsc('created_at');
    const rs = await store.query(pred);
    const list: Array<BackupRecord> = [];
    while (rs.goToNextRow()) {
      const it: BackupRecord = {
        date: rs.getString(rs.getColumnIndex('date')),
        type: rs.getLong(rs.getColumnIndex('type')),
        content: rs.getString(rs.getColumnIndex('content')),
        amount: rs.getDouble(rs.getColumnIndex('amount')),
        created_at: rs.getLong(rs.getColumnIndex('created_at'))
      };
      list.push(it);
    }
    rs.close();
    return list;
  }

  // 导入去重：同日期+类型+内容+金额视为同一条
  static async recordExists(date: string, type: number, content: string, amount: number): Promise<boolean> {
    const store = await Db.getStore();
    const sql = 'SELECT COUNT(*) AS c FROM records WHERE date = ? AND type = ? AND content = ? AND amount = ?';
    const rs = await store.querySql(sql, [date, type, content, amount]);
    let exists = false;
    if (rs.goToNextRow()) {
      exists = rs.getLong(rs.getColumnIndex('c')) > 0;
    }
    rs.close();
    return exists;
  }

  // 设置项
  static async getSetting(key: string, defVal: string): Promise<string> {
    const store = await Db.getStore();
    const rs = await store.querySql('SELECT value FROM settings WHERE key = ?', [key]);
    let out = defVal;
    if (rs.goToNextRow()) {
      out = rs.getString(rs.getColumnIndex('value'));
    }
    rs.close();
    return out;
  }

  static async setSetting(key: string, value: string): Promise<void> {
    const store = await Db.getStore();
    await store.executeSql('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', [key, value]);
  }
}
