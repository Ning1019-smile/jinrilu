import { router, promptAction } from '@kit.ArkUI';
import { Db } from '../common/Db';
import { RecordItem, DaySummary, DayParams, RecType } from '../common/Types';
import { Theme, PHRASE_SEP } from '../common/Style';
import { todayStr, dayTitle, shiftDate, fmtAmount } from '../common/DateUtil';

// 当日页：顶部花销统计 + 事件/行程/收支三区，一行记一条
@Entry
@Component
struct DayPage {
  @StorageProp('fontScale') fsNum: number = 1;
  @StorageProp('quickPhrases') quickStr: string = '';
  @StorageProp('topAvoidPx') topAvoidPx: number = 0;
  @StorageProp('bottomAvoidPx') bottomAvoidPx: number = 0;
  @State dateStr: string = todayStr();
  @State segIndex: number = 0; // 0事件 1行程 2收支
  @State records: Array<RecordItem> = [];
  @State daySum: DaySummary = { expense: 0, income: 0 };
  @State inputText: string = '';
  @State amountText: string = '';
  @State noteText: string = '';
  @State isExpense: boolean = true;
  @State editingId: number = -1; // >=0 表示正在编辑该条收支
  @State lastDeleted: RecordItem | null = null;
  private undoTimer: number = -1;

  aboutToAppear(): void {
    const p = router.getParams() as DayParams;
    if (p !== null && p !== undefined && p.date.length === 10) {
      this.dateStr = p.date;
    }
    this.reload();
  }

  async reload(): Promise<void> {
    this.records = await Db.getDayRecords(this.dateStr);
    this.daySum = await Db.getDaySummary(this.dateStr);
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  chips(): Array<string> {
    return this.quickStr.split(PHRASE_SEP).filter((s: string) => s.length > 0);
  }

  currentType(): number {
    if (this.segIndex === 0) {
      return RecType.Event;
    }
    return RecType.Place;
  }

  filtered(): Array<RecordItem> {
    if (this.segIndex === 2) {
      return this.records.filter((r: RecordItem) => r.type === RecType.Expense || r.type === RecType.Income);
    }
    const t: number = this.currentType();
    return this.records.filter((r: RecordItem) => r.type === t);
  }

  switchTab(i: number): void {
    this.segIndex = i;
    this.inputText = '';
    this.editingId = -1;
  }

  shiftDay(delta: number): void {
    this.dateStr = shiftDate(this.dateStr, delta);
    this.reload();
  }

  jumpToday(): void {
    this.dateStr = todayStr();
    this.reload();
  }

  // 事件/行程：一行记一条
  async addLine(): Promise<void> {
    const text: string = this.inputText.trim();
    if (text.length === 0) {
      return;
    }
    if (this.editingId >= 0) {
      // 编辑模式：更新原记录
      const it: RecordItem = {
        id: this.editingId,
        date: this.dateStr,
        type: this.currentType(),
        content: text,
        amount: 0
      };
      await Db.updateRecord(this.editingId, it);
      this.editingId = -1;
      this.inputText = '';
      this.bumpData();
      this.reload();
      promptAction.showToast({ message: '已修改' });
      return;
    }
    const it: RecordItem = {
      id: 0,
      date: this.dateStr,
      type: this.currentType(),
      content: text,
      amount: 0
    };
    await Db.insertRecord(it);
    this.inputText = '';
    this.bumpData();
    this.reload();
    promptAction.showToast({ message: '已记一笔' });
  }

  // 收支：金额 + 备注
  async addFinance(): Promise<void> {
    const amt: number = parseFloat(this.amountText);
    if (isNaN(amt) || amt <= 0) {
      promptAction.showToast({ message: '请输入金额' });
      return;
    }
    if (this.editingId >= 0) {
      // 编辑模式：更新原记录
      const it: RecordItem = {
        id: this.editingId,
        date: this.dateStr,
        type: this.isExpense ? RecType.Expense : RecType.Income,
        content: this.noteText.trim(),
        amount: amt
      };
      await Db.updateRecord(this.editingId, it);
      this.editingId = -1;
      this.amountText = '';
      this.noteText = '';
      this.bumpData();
      this.reload();
      promptAction.showToast({ message: '已修改' });
      return;
    }
    const it: RecordItem = {
      id: 0,
      date: this.dateStr,
      type: this.isExpense ? RecType.Expense : RecType.Income,
      content: this.noteText.trim(),
      amount: amt
    };
    await Db.insertRecord(it);
    this.amountText = '';
    this.noteText = '';
    this.bumpData();
    this.reload();
    promptAction.showToast({ message: '已记一笔' });
  }

  // 点击记录进入编辑：内容回填到输入区（事件/行程/收支通用）
  startEdit(it: RecordItem): void {
    this.editingId = it.id;
    if (it.type === RecType.Expense || it.type === RecType.Income) {
      this.isExpense = it.type === RecType.Expense;
      this.amountText = fmtAmount(it.amount);
      this.noteText = it.content;
    } else {
      this.segIndex = it.type;
      this.inputText = it.content;
    }
  }

  async deleteOne(it: RecordItem): Promise<void> {
    await Db.deleteRecord(it.id);
    if (this.editingId === it.id) {
      this.editingId = -1;
    }
    this.lastDeleted = it;
    this.bumpData();
    this.reload();
    if (this.undoTimer >= 0) {
      clearTimeout(this.undoTimer);
    }
    this.undoTimer = setTimeout(() => {
      this.lastDeleted = null;
    }, 5000);
  }

  async undoDelete(): Promise<void> {
    if (this.lastDeleted !== null) {
      await Db.insertRecord(this.lastDeleted);
      this.lastDeleted = null;
      this.bumpData();
      this.reload();
    }
  }

  // 通知日历/回顾页数据已变化，自动刷新
  bumpData(): void {
    const v = AppStorage.get<number>('dataVersion') ?? 0;
    AppStorage.setOrCreate('dataVersion', v + 1);
  }

  build() {
    Column() {
      // 顶栏：返回 + 今天
      Row() {
        Text('‹')
          .fontSize(this.fz(26))
          .fontColor(Theme.text)
          .onClick(() => router.back())
          .padding({ left: 12, right: 12 })
        Blank()
        Text('今天')
          .fontSize(this.fz(15))
          .fontColor(Theme.brandText)
          .onClick(() => this.jumpToday())
          .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .height(44)

      // 日期切换：‹ 10月15日 周四 ›
      Row() {
        Text('‹')
          .fontSize(this.fz(22))
          .fontColor(Theme.textMut)
          .onClick(() => this.shiftDay(-1))
          .padding({ left: 20, right: 20 })
        Text(dayTitle(this.dateStr))
          .fontSize(this.fz(18))
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
        Text('›')
          .fontSize(this.fz(22))
          .fontColor(Theme.textMut)
          .onClick(() => this.shiftDay(1))
          .padding({ left: 20, right: 20 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 4, bottom: 8 })

      // 当日花销统计（常驻顶部）
      Row() {
        Column() {
          Text('本日支出')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
          Text('¥' + fmtAmount(this.daySum.expense))
            .fontSize(this.fz(26))
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.expense)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('本日收入')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
          Text('¥' + fmtAmount(this.daySum.income))
            .fontSize(this.fz(20))
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.income)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('92%')
      .backgroundColor(Theme.card)
      .borderRadius(12)
      .padding(16)
      .margin({ top: 4, bottom: 10 })

      // 分区：事件 / 行程 / 收支
      Row() {
        Text('事件')
          .fontSize(this.fz(15))
          .fontColor(this.segIndex === 0 ? Theme.brandText : Theme.textMut)
          .fontWeight(this.segIndex === 0 ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor(this.segIndex === 0 ? Theme.brandSoft : Color.Transparent)
          .onClick(() => this.switchTab(0))
        Text('行程')
          .fontSize(this.fz(15))
          .fontColor(this.segIndex === 1 ? Theme.brandText : Theme.textMut)
          .fontWeight(this.segIndex === 1 ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor(this.segIndex === 1 ? Theme.brandSoft : Color.Transparent)
          .onClick(() => this.switchTab(1))
        Text('收支')
          .fontSize(this.fz(15))
          .fontColor(this.segIndex === 2 ? Theme.brandText : Theme.textMut)
          .fontWeight(this.segIndex === 2 ? FontWeight.Medium : FontWeight.Regular)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .borderRadius(18)
          .backgroundColor(this.segIndex === 2 ? Theme.brandSoft : Color.Transparent)
          .onClick(() => this.switchTab(2))
      }
      .width('92%')
      .backgroundColor(Theme.segBg)
      .borderRadius(20)
      .padding(3)

      // 记录列表
      List() {
        if (this.filtered().length === 0) {
          ListItem() {
            Column() {
              Text('这一天还没有记录')
                .fontSize(this.fz(15))
                .fontColor(Theme.textMut)
              Text(this.segIndex === 2 ? '在下方记一笔收支吧' : '在下方输入一行，回车即可')
                .fontSize(this.fz(13))
                .fontColor(Theme.textMut)
                .margin({ top: 6 })
            }
            .width('100%')
            .padding({ top: 40, bottom: 40 })
          }
        }
        ForEach(this.filtered(), (it: RecordItem) => {
          ListItem() {
            if (it.type === RecType.Expense || it.type === RecType.Income) {
              this.financeRow(it)
            } else {
              this.lineRow(it)
            }
          }
          .swipeAction({ end: this.delBtn(it) })
        }, (it: RecordItem) => it.id.toString() + '#' + it.type.toString() + '#' + it.content + '#' + it.amount.toString())
      }
      .layoutWeight(1)
      .width('92%')
      .margin({ top: 8 })
      .scrollBar(BarState.Off)

      // 删除撤销条
      if (this.lastDeleted !== null) {
        Row() {
          Text('已删除一条记录')
            .fontSize(this.fz(14))
            .fontColor(Theme.textMut)
          Text('撤销')
            .fontSize(this.fz(14))
            .fontColor(Theme.brand)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 16 })
            .onClick(() => this.undoDelete())
        }
        .width('92%')
        .justifyContent(FlexAlign.Center)
        .padding(10)
        .backgroundColor(Theme.card)
        .borderRadius(12)
        .margin({ top: 8 })
      }

      // 底部输入区
      if (this.segIndex === 2) {
        this.financeInput()
      } else {
        this.lineInput()
      }
    }
    .padding({ top: px2vp(this.topAvoidPx), bottom: px2vp(this.bottomAvoidPx) })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, fingers: 1, distance: 50 })
        .onActionEnd((event: GestureEvent) => {
          // 左右滑动切换 事件/行程/收支
          if (event.offsetX < 0 && this.segIndex < 2) {
            this.switchTab(this.segIndex + 1);
          } else if (event.offsetX > 0 && this.segIndex > 0) {
            this.switchTab(this.segIndex - 1);
          }
        })
    )
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }

  // 事件/行程一行记录
  @Builder
  lineRow(it: RecordItem) {
    Row() {
      Column()
        .width(5)
        .height(5)
        .borderRadius(3)
        .backgroundColor(Theme.brand)
        .margin({ right: 10 })
      Text(it.content)
        .fontSize(this.fz(16))
        .fontColor(Theme.text)
        .layoutWeight(1)
    }
    .width('100%')
    .height(52)
    .backgroundColor(Theme.card)
    .borderRadius(12)
    .border({ width: this.editingId === it.id ? 1.5 : 0, color: Theme.brand })
    .padding({ left: 14, right: 14 })
    .margin({ bottom: 8 })
    .onClick(() => this.startEdit(it))
  }

  // 收支行
  @Builder
  financeRow(it: RecordItem) {
    Row() {
      Text(it.type === RecType.Expense ? '支出' : '收入')
        .fontSize(this.fz(12))
        .fontColor(it.type === RecType.Expense ? Theme.expense : Theme.income)
        .backgroundColor(it.type === RecType.Expense ? Theme.tagExpenseBg : Theme.brandSoft)
        .borderRadius(6)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .margin({ right: 10 })
      Text(it.content.length === 0 ? '—' : it.content)
        .fontSize(this.fz(15))
        .fontColor(it.content.length === 0 ? Theme.textMut : Theme.text)
        .layoutWeight(1)
        .maxLines(1)
      Text((it.type === RecType.Expense ? '-' : '+') + fmtAmount(it.amount))
        .fontSize(this.fz(17))
        .fontWeight(FontWeight.Medium)
        .fontColor(it.type === RecType.Expense ? Theme.expense : Theme.income)
    }
    .width('100%')
    .height(52)
    .backgroundColor(Theme.card)
    .borderRadius(12)
    .border({ width: this.editingId === it.id ? 1.5 : 0, color: Theme.brand })
    .padding({ left: 14, right: 14 })
    .margin({ bottom: 8 })
    .onClick(() => this.startEdit(it))
  }

  @Builder
  delBtn(it: RecordItem) {
    Row() {
      Text('删除')
        .fontSize(this.fz(14))
        .fontColor(Color.White)
    }
    .width(64)
    .height(44)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.deleteRed)
    .borderRadius(12)
    .margin({ left: 8, bottom: 8 })
    .onClick(() => {
      this.deleteOne(it);
    })
  }

  // 事件/行程输入：一行 + 常用语
  @Builder
  lineInput() {
    Column() {
      if (this.segIndex === 0 && this.chips().length > 0) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.chips(), (p: string) => {
            Text(p)
              .fontSize(this.fz(14))
              .fontColor(Theme.brandText)
              .backgroundColor(Theme.brandSoft)
              .borderRadius(15)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.inputText = p;
              })
          }, (p: string) => p)
        }
        .width('100%')
        .margin({ bottom: 8 })
      }

      if (this.editingId >= 0) {
        Row() {
          Text('正在编辑，改完点保存')
            .fontSize(this.fz(13))
            .fontColor(Theme.brandText)
            .layoutWeight(1)
          Text('取消')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
            .onClick(() => {
              this.editingId = -1;
              this.inputText = '';
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      Row() {
        TextInput({
          text: this.inputText,
          placeholder: this.segIndex === 0 ? '记一件事，如：早上做了30个俯卧撑' : '记一个地点，如：人民公园'
        })
          .fontSize(this.fz(16))
          .placeholderFont({ size: this.fz(14) })
          .placeholderColor(Theme.textMut)
          .height(46)
          .layoutWeight(1)
          .backgroundColor(Theme.card)
          .borderRadius(12)
          .enterKeyType(EnterKeyType.Done)
          .onChange((v: string) => {
            this.inputText = v;
          })
          .onSubmit(() => {
            this.addLine();
          })
        Button(this.editingId >= 0 ? '保存' : '添加')
          .fontSize(this.fz(15))
          .height(46)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor(Theme.brand)
          .borderRadius(12)
          .margin({ left: 8 })
          .onClick(() => this.addLine())
      }
      .width('100%')
    }
    .width('92%')
    .padding({ top: 8, bottom: 16 })
  }

  // 收支输入：支/收切换 + 金额 + 备注
  @Builder
  financeInput() {
    Column() {
      Row() {
        Text('支出')
          .fontSize(this.fz(15))
          .fontColor(this.isExpense ? Theme.expense : Theme.textMut)
          .backgroundColor(this.isExpense ? Theme.tagExpenseBg : Theme.card)
          .borderRadius(15)
          .padding({ left: 18, right: 18, top: 7, bottom: 7 })
          .onClick(() => {
            this.isExpense = true;
          })
        Text('收入')
          .fontSize(this.fz(15))
          .fontColor(!this.isExpense ? Theme.brandText : Theme.textMut)
          .backgroundColor(!this.isExpense ? Theme.brandSoft : Theme.card)
          .borderRadius(15)
          .padding({ left: 18, right: 18, top: 7, bottom: 7 })
          .margin({ left: 10 })
          .onClick(() => {
            this.isExpense = false;
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      if (this.editingId >= 0) {
        Row() {
          Text('正在编辑，改完点保存')
            .fontSize(this.fz(13))
            .fontColor(Theme.brandText)
            .layoutWeight(1)
          Text('取消')
            .fontSize(this.fz(13))
            .fontColor(Theme.textMut)
            .onClick(() => {
              this.editingId = -1;
              this.amountText = '';
              this.noteText = '';
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      Row() {
        TextInput({ text: this.amountText, placeholder: '金额' })
          .fontSize(this.fz(18))
          .placeholderFont({ size: this.fz(14) })
          .placeholderColor(Theme.textMut)
          .height(46)
          .width('38%')
          .backgroundColor(Theme.card)
          .borderRadius(12)
          .inputFilter('[0-9.]')
          .onChange((v: string) => {
            this.amountText = v;
          })
        TextInput({ text: this.noteText, placeholder: this.isExpense ? '花在哪了（可不填）' : '收自哪里（可不填）' })
          .fontSize(this.fz(15))
          .placeholderFont({ size: this.fz(14) })
          .placeholderColor(Theme.textMut)
          .height(46)
          .layoutWeight(1)
          .backgroundColor(Theme.card)
          .borderRadius(12)
          .margin({ left: 8 })
          .enterKeyType(EnterKeyType.Done)
          .onChange((v: string) => {
            this.noteText = v;
          })
          .onSubmit(() => {
            this.addFinance();
          })
        Button(this.editingId >= 0 ? '保存' : '添加')
          .fontSize(this.fz(15))
          .height(46)
          .fontColor($r('app.color.on_brand'))
          .backgroundColor(Theme.brand)
          .borderRadius(12)
          .margin({ left: 8 })
          .onClick(() => this.addFinance())
      }
      .width('100%')
    }
    .width('92%')
    .padding({ top: 8, bottom: 16 })
  }
}
