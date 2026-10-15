export const WEEK_CN: Array<string> = ['日', '一', '二', '三', '四', '五', '六'];

export function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

export function toDateStr(d: Date): string {
  return d.getFullYear().toString() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

export function todayStr(): string {
  return toDateStr(new Date());
}

// m 传 1-12
export function daysInMonth(y: number, m: number): number {
  return new Date(y, m, 0).getDate();
}

// 1号是星期几：0=周日
export function firstWeekday(y: number, m: number): number {
  return new Date(y, m - 1, 1).getDay();
}

export function shiftDate(dateStr: string, delta: number): string {
  const p: Array<string> = dateStr.split('-');
  const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  d.setDate(d.getDate() + delta);
  return toDateStr(d);
}

// '2026-10-15' -> '10月15日 周四'
export function dayTitle(dateStr: string): string {
  const p: Array<string> = dateStr.split('-');
  const d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  return Number(p[1]).toString() + '月' + Number(p[2]).toString() + '日 周' + WEEK_CN[d.getDay()];
}

// 金额显示：整数不带小数
export function fmtAmount(n: number): string {
  if (n % 1 === 0) {
    return Math.round(n).toString();
  }
  return n.toFixed(2);
}
