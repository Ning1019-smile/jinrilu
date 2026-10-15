// 记录类型常量（存库用数字）
export class RecType {
  static readonly Event: number = 0;    // 事件
  static readonly Place: number = 1;    // 行程
  static readonly Expense: number = 2;  // 支出
  static readonly Income: number = 3;   // 收入
}

// 一条记录：事件/行程记内容，收支记金额+备注
export interface RecordItem {
  id: number;
  date: string;   // yyyy-MM-dd
  type: number;   // RecType
  content: string;
  amount: number;
}

// 日历单元格标记：圆点=有事件或行程，数字=支出金额
export interface DayMark {
  day: number;
  hasEventOrPlace: boolean;
  expense: number;
}

// 月/日汇总
export interface MonthSummary {
  recordDays: number;
  expense: number;
  income: number;
}

export interface DaySummary {
  expense: number;
  income: number;
}

// 回顾页：常去地点排行 / 最大一笔花销
export interface PlaceStat {
  content: string;
  count: number;
}

export interface MonthHighlight {
  content: string;
  amount: number;
}

// 备份文件中的一条记录
export interface BackupRecord {
  date: string;
  type: number;
  content: string;
  amount: number;
  created_at: number;
}

// 页面跳转参数
export class DayParams {
  date: string = '';
}

export function typeLabel(t: number): string {
  if (t === RecType.Event) {
    return '事件';
  }
  if (t === RecType.Place) {
    return '行程';
  }
  if (t === RecType.Expense) {
    return '支出';
  }
  return '收入';
}
