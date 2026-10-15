import { router } from '@kit.ArkUI';
import { Db } from '../common/Db';
import { RecordItem, MonthSummary, PlaceStat, MonthHighlight, DayParams, typeLabel } from '../common/Types';
import { Theme } from '../common/Style';
import { pad2, fmtAmount } from '../common/DateUtil';

// 回顾页：关键词搜索 + 当月回顾
@Component
export struct ReviewPage {
  @StorageProp('fontScale') fsNum: number = 1;
  @State kw: string = '';
  @State searched: boolean = false;
  @State results: Array<RecordItem> = [];
  @State summary: MonthSummary = { recordDays: 0, expense: 0, income: 0 };
  @State placeStats: Array<PlaceStat> = [];
  @State maxExpense: MonthHighlight | null = null;
  @StorageProp('dataVersion') @Watch('onDataChanged') dataVersion: number = 0;
  private curYear: number = new Date().getFullYear();
  private curMonth: number = new Date().getMonth() + 1;

  aboutToAppear(): void {
    this.loadMonth();
  }

  async loadMonth(): Promise<void> {
    const prefix: string = this.curYear.toString() + '-' + pad2(this.curMonth);
    this.summary = await Db.getMonthSummary(prefix);
    this.placeStats = await Db.getPlaceStats(prefix);
    this.maxExpense = await Db.getMaxExpense(prefix);
  }

  // 记一笔/删一笔后自动刷新本页数据
  onDataChanged(): void {
    this.loadMonth();
    if (this.searched) {
      this.doSearch();
    }
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  async doSearch(): Promise<void> {
    const kw: string = this.kw.trim();
    if (kw.length === 0) {
      this.searched = false;
      return;
    }
    this.results = await Db.search(kw);
    this.searched = true;
  }

  openDay(dateStr: string): void {
    const p = new DayParams();
    p.date = dateStr;
    router.pushUrl({ url: 'pages/DayPage', params: p });
  }

  build() {
    Scroll() {
      Column() {
        Text('回顾')
          .fontSize(this.fz(22))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .width('92%')
          .margin({ top: 12, bottom: 10 })

        // 搜索
        Row() {
          TextInput({ text: this.kw, placeholder: '搜索做过的事、去过的地方…' })
            .fontSize(this.fz(16))
            .placeholderFont({ size: this.fz(14) })
            .placeholderColor(Theme.textMut)
            .height(46)
            .layoutWeight(1)
            .backgroundColor(Theme.card)
            .borderRadius(12)
            .enterKeyType(EnterKeyType.Search)
            .onChange((v: string) => {
              this.kw = v;
            })
            .onSubmit(() => {
              this.doSearch();
            })
          Button('搜索')
            .fontSize(this.fz(15))
            .height(46)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor(Theme.brand)
            .borderRadius(12)
            .margin({ left: 8 })
            .onClick(() => this.doSearch())
        }
        .width('92%')

        // 搜索结果
        if (this.searched) {
          Column() {
            Text(this.results.length === 0 ? '没有找到相关记录' : '找到 ' + this.results.length.toString() + ' 条记录')
              .fontSize(this.fz(13))
              .fontColor(Theme.textMut)
              .width('100%')
              .margin({ bottom: 8 })
            ForEach(this.results, (it: RecordItem) => {
              Column() {
                Row() {
                  Text(typeLabel(it.type))
                    .fontSize(this.fz(11))
                    .fontColor(Theme.textMut)
                    .backgroundColor(Theme.bg)
                    .borderRadius(6)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  Text(dayShort(it.date))
                    .fontSize(this.fz(12))
                    .fontColor(Theme.textMut)
                    .margin({ left: 8 })
                }
                .width('100%')
                Text(it.content.length === 0 ? (it.type === 2 ? '支出 ¥' + fmtAmount(it.amount) : '收入 ¥' + fmtAmount(it.amount)) : it.content)
                  .fontSize(this.fz(15))
                  .fontColor(Theme.text)
                  .width('100%')
                  .margin({ top: 4 })
                  .maxLines(1)
              }
              .width('100%')
              .backgroundColor(Theme.card)
              .borderRadius(12)
              .padding(12)
              .margin({ bottom: 8 })
              .onClick(() => this.openDay(it.date))
            }, (it: RecordItem) => it.id.toString() + '#' + it.type.toString() + '#' + it.content + '#' + it.amount.toString())
          }
          .width('92%')
          .margin({ top: 12 })
        }

        // 当月回顾
        Column() {
          Text('本月回顾')
            .fontSize(this.fz(16))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .width('100%')
            .margin({ bottom: 10 })

          Row() {
            Text('记录天数').fontSize(this.fz(14)).fontColor(Theme.textMut).layoutWeight(1)
            Text(this.summary.recordDays.toString() + ' 天')
              .fontSize(this.fz(15))
              .fontColor(Theme.text)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })

          Row() {
            Text('本月支出').fontSize(this.fz(14)).fontColor(Theme.textMut).layoutWeight(1)
            Text('¥' + fmtAmount(this.summary.expense))
              .fontSize(this.fz(15))
              .fontColor(Theme.expense)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })

          Row() {
            Text('本月收入').fontSize(this.fz(14)).fontColor(Theme.textMut).layoutWeight(1)
            Text('¥' + fmtAmount(this.summary.income))
              .fontSize(this.fz(15))
              .fontColor(Theme.income)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })

          Divider().color(Theme.line).margin({ top: 6, bottom: 10 })

          Text('常去的地方')
            .fontSize(this.fz(14))
            .fontColor(Theme.textMut)
            .width('100%')
          if (this.placeStats.length === 0) {
            Text('本月还没有行程记录')
              .fontSize(this.fz(14))
              .fontColor(Theme.textMut)
              .width('100%')
              .margin({ top: 6, bottom: 6 })
          } else {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.placeStats, (ps: PlaceStat) => {
                Text(ps.content + ' · ' + ps.count.toString() + '次')
                  .fontSize(this.fz(13))
                  .fontColor(Theme.brandText)
                  .backgroundColor(Theme.brandSoft)
                  .borderRadius(14)
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .margin({ right: 8, bottom: 8, top: 6 })
              }, (ps: PlaceStat) => ps.content + '#' + ps.count.toString())
            }
            .width('100%')
          }

          Divider().color(Theme.line).margin({ top: 6, bottom: 10 })

          Row() {
            Text('本月最大一笔花销').fontSize(this.fz(14)).fontColor(Theme.textMut).layoutWeight(1)
            if (this.maxExpense !== null) {
              Text('¥' + fmtAmount(this.maxExpense.amount) + (this.maxExpense.content.length === 0 ? '' : ' · ' + this.maxExpense.content))
                .fontSize(this.fz(15))
                .fontColor(Theme.expense)
                .fontWeight(FontWeight.Medium)
                .textAlign(TextAlign.End)
            } else {
              Text('暂无').fontSize(this.fz(14)).fontColor(Theme.textMut)
            }
          }
          .width('100%')
        }
        .width('92%')
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .padding(16)
        .margin({ top: 12, bottom: 24 })
      }
      .width('100%')
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}

// '2026-10-15' -> '2026年10月15日'
function dayShort(dateStr: string): string {
  const p: Array<string> = dateStr.split('-');
  return p[0] + '年' + Number(p[1]).toString() + '月' + Number(p[2]).toString() + '日';
}
