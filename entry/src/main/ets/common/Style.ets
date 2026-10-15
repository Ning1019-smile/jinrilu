// 颜色统一走资源引用：base/dark 两套自动跟随系统深浅色
export class Theme {
  static readonly brand: Resource = $r('app.color.brand');
  static readonly brandSoft: Resource = $r('app.color.brand_soft');
  static readonly brandText: Resource = $r('app.color.brand_text');
  static readonly text: Resource = $r('app.color.text_primary');
  static readonly textMut: Resource = $r('app.color.text_secondary');
  static readonly bg: Resource = $r('app.color.page_bg');
  static readonly card: Resource = $r('app.color.card_bg');
  static readonly line: Resource = $r('app.color.line');
  static readonly expense: Resource = $r('app.color.expense');
  static readonly income: Resource = $r('app.color.income');
  static readonly deleteRed: Resource = $r('app.color.delete_red');
  static readonly onBrand: Resource = $r('app.color.on_brand');
  static readonly segBg: Resource = $r('app.color.seg_bg');
  static readonly tagExpenseBg: Resource = $r('app.color.tag_expense_bg');
}

// 常用语之间的分隔符
export const PHRASE_SEP: string = '|';

// 默认常用语
export const DEFAULT_PHRASES: string = '散步|买菜|量血压|做操|下棋|接孙子';
