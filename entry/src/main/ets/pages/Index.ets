import { CalendarPage } from './CalendarPage';
import { ReviewPage } from './ReviewPage';
import { SettingsPage } from './SettingsPage';
import { Theme } from '../common/Style';

// 主页：底部三个入口——日历 / 回顾 / 设置
@Entry
@Component
struct Index {
  @StorageProp('fontScale') fsNum: number = 1;
  @StorageProp('topAvoidPx') topAvoidPx: number = 0;
  @StorageProp('bottomAvoidPx') bottomAvoidPx: number = 0;
  @State barIndex: number = 0;
  private tabsController: TabsController = new TabsController();

  aboutToAppear(): void {
    // 页面重建（如深浅色切换）时回到上次的页签
    this.barIndex = AppStorage.get<number>('lastTab') ?? 0;
  }

  fz(base: number): number {
    return Math.round(base * this.fsNum);
  }

  @Builder
  tabItem(title: string, idx: number) {
    Column() {
      Text(title)
        .fontSize(this.fz(16))
        .fontWeight(this.barIndex === idx ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.barIndex === idx ? Theme.brand : Theme.textMut)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      // 点击立即高亮并切页，避免内容先切、颜色后到的延迟感
      this.barIndex = idx;
      this.tabsController.changeIndex(idx);
    })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.barIndex, controller: this.tabsController }) {
      TabContent() {
        CalendarPage()
      }
      .tabBar(this.tabItem('日历', 0))

      TabContent() {
        ReviewPage()
      }
      .tabBar(this.tabItem('回顾', 1))

      TabContent() {
        SettingsPage()
      }
      .tabBar(this.tabItem('设置', 2))
    }
    .scrollable(true)
    .barHeight(54)
    .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
      // 滑动切页动画一开始就同步高亮，消除绿色延迟
      this.barIndex = targetIndex;
    })
    .onChange((index: number) => {
      this.barIndex = index;
      AppStorage.setOrCreate('lastTab', index);
    })
    .padding({ top: px2vp(this.topAvoidPx), bottom: px2vp(this.bottomAvoidPx) })
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
