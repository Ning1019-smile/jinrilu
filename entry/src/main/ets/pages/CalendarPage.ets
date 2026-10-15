import { router } from '@kit.ArkUI';
import { Db } from '../common/Db';
import { DayMark, MonthSummary, DayParams } from '../common/Types';
import { Theme } from '../common/Style';
import { WEEK_CN, daysInMonth, firstWeekday, pad2, todayStr, fmtAmount } from '../common/DateUtil';

// 月历单元格数据
export class Cell {
  date: string = '';
  day: number = 0;
  hasEventOrPlace: boolean = false;
  expense: number = -1; // -1 表示不显示金额
  isToday: boolean = false;
  blank: boolean = false;
}

// 月视图日历（首页）
@Component
export struct CalendarPage {
  @StorageProp('fontScale') fsNum: number = 1;
  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State cells: Array<Cell> = [];
  @State summary: MonthSummary = { recordDays: 0, expense: 0, income: 0 };
  @State todayDate: string = todayStr();
  @StorageProp('dataVersion') @Watch('onDataChanged') dataVersion: number = 0;

  aboutToAppear(): void {
    const d = new Date();
    this.year = d.getFullYear();
    this.month = d.getMonth() + 1;
    this.reload();
  }

  async reload(): Promise<void> {
    const prefix: string = this.year.toString() + '-' + pad2(this.month);
    const marks: Array<DayMark> = await Db.getMonthMarks(prefix);
    const map: Map<string, DayMark> = new Map();
    for (let i = 0; i < marks.length; i++) {
      map.set(prefix + '-' + pad2(marks[i].day), marks[i]);
    }
    const total: number = daysInMonth(this.year, this.month);
    const first: number = firstWeekday(this.year, this.month);
    const arr: Array<Cell> = [];
    for (let i = 0; i < first; i++) {
      const c = new Cell();
      c.blank = true;
      arr.push(c);
    }
    for (let day = 1; day <= total; day++) {
      const dateStr: string = prefix + '-' + pad2(day);
      const c = new Cell();
      c.date = dateStr;
      c.day = day;
      c.isToday = dateStr === this.todayDate;
      const mk = map.get(dateStr);
      if (mk !== undefined) {
        c.hasEventOrPlace = mk.hasEventOrPlace;
        if (mk.expense > 0) {
          c.expense = mk.expense;
        }
      }
      arr.push(c);
    }
    this.cells = arr;
    this.summary = await Db.getMonthSummary(prefix);
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  gridRows(): number {
    return Math.max(1, Math.ceil(this.cells.length / 7));
  }

  prevMonth(): void {
    if (this.month === 1) {
      this.year -= 1;
      this.month = 12;
    } else {
      this.month -= 1;
    }
    this.reload();
  }

  nextMonth(): void {
    if (this.month === 12) {
      this.year += 1;
      this.month = 1;
    } else {
      this.month += 1;
    }
    this.reload();
  }

  backToday(): void {
    const d = new Date();
    this.year = d.getFullYear();
    this.month = d.getMonth() + 1;
    this.reload();
  }

  openDay(dateStr: string): void {
    const p = new DayParams();
    p.date = dateStr;
    router.pushUrl({ url: 'pages/DayPage', params: p });
  }

  // 点击年月：弹出日期选择器，跳到所选日期所在月份
  showDatePicker(): void {
    DatePickerDialog.show({
      start: new Date(1990, 0, 1),
      end: new Date(2050, 11, 31),
      selected: new Date(this.year, this.month - 1, 1),
      lunar: false,
      onDateAccept: (value: Date) => {
        this.year = value.getFullYear();
        this.month = value.getMonth() + 1;
        this.reload();
      }
    });
  }

  // 记一笔/删一笔后自动刷新月历
  onDataChanged(): void {
    this.reload();
  }

  build() {
    Column() {
      // 顶部：年月 + 切月 + 回到今天
      Row() {
        Text('‹')
          .fontSize(this.fz(26))
          .fontColor(Theme.textMut)
          .onClick(() => this.prevMonth())
          .padding({ left: 8, right: 12 })
        Row() {
          Text(this.year.toString() + '年' + this.month.toString() + '月')
            .fontSize(this.fz(20))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
          Text('▾')
            .fontSize(this.fz(18))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.textMut)
            .margin({ left: 6 })
        }
        .onClick(() => this.showDatePicker())
        Text('›')
          .fontSize(this.fz(26))
          .fontColor(Theme.textMut)
          .onClick(() => this.nextMonth())
          .padding({ left: 12, right: 8 })
        Blank()
        Text('回到今天')
          .fontSize(this.fz(15))
          .fontColor(Theme.brandText)
          .backgroundColor(Theme.brandSoft)
          .borderRadius(16)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => this.backToday())
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 12, bottom: 8 })

      // 星期行
      Row() {
        ForEach(WEEK_CN, (w: string) => {
          Text(w)
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }, (w: string) => w)
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })

      // 日历格子
      Grid() {
        ForEach(this.cells, (c: Cell) => {
          GridItem() {
            if (c.blank) {
              Column()
            } else {
              this.dayCell(c)
            }
          }
        }, (c: Cell, idx: number) => idx.toString() + '#' + c.date + '#' + (c.hasEventOrPlace ? 'e' : '') + (c.expense >= 0 ? c.expense.toString() : ''))
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(4)
      .height(this.gridRows() * 58 + (this.gridRows() - 1) * 4)
      .width('100%')
      .padding({ left: 8, right: 8 })

      // 标注说明
      Text('数字为当日支出，圆点表示当天有事件或行程')
        .fontSize(this.fz(12))
        .fontColor(Theme.textMut)
        .width('92%')
        .margin({ top: 8 })

      // 当月小结
      Row() {
        Text('记录 ' + this.summary.recordDays.toString() + ' 天')
          .fontSize(this.fz(14))
          .fontColor(Theme.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('支出 ¥' + fmtAmount(this.summary.expense))
          .fontSize(this.fz(14))
          .fontColor(Theme.expense)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('收入 ¥' + fmtAmount(this.summary.income))
          .fontSize(this.fz(14))
          .fontColor(Theme.income)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('92%')
      .backgroundColor(Theme.card)
      .borderRadius(12)
      .padding({ top: 12, bottom: 12 })
      .margin({ top: 12 })

      Text('所有数据仅保存在本机')
        .fontSize(this.fz(12))
        .fontColor(Theme.textMut)
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }

  @Builder
  dayCell(c: Cell) {
    Column() {
      if (c.isToday) {
        Column() {
          Text(c.day.toString())
            .fontSize(this.fz(15))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.on_brand'))
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor(Theme.brand)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          Text(c.day.toString())
            .fontSize(this.fz(15))
            .fontColor(Theme.text)
        }
        .width(30)
        .height(30)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      // 标记区固定高度：日期数字位置不随有无标记变化
      Column() {
        if (c.expense >= 0) {
          Text(fmtAmount(c.expense))
            .fontSize(this.fz(11))
            .fontColor(Theme.brandText)
            .maxLines(1)
        }
        if (c.hasEventOrPlace) {
          Column()
            .width(5)
            .height(5)
            .borderRadius(3)
            .backgroundColor(Theme.brand)
            .margin({ top: c.expense >= 0 ? 1 : 0 })
        }
      }
      .width('100%')
      .height(24)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 2 })
    }
    .width('100%')
    .height(58)
    .onClick(() => this.openDay(c.date))
  }
}
