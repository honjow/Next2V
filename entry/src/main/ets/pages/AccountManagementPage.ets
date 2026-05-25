import { common } from '@kit.AbilityKit'
import {
  AccountSessionCoordinator,
  AccountStore,
  AppStrings,
  ConciseListRow,
  GroupedListSection,
  ListDivider as SharedListDivider,
  SecondaryListScaffold,
  SectionHeader as SharedSectionHeader,
  ThemeConstants
} from 'shared'
import type { AccountRecord } from 'shared'
import { AccountPageCoordinator } from '../model/AccountPageCoordinator'

@Component
export struct AccountManagementPage {
  @Consume('ns') ns: NavPathStack
  @State private accounts: AccountRecord[] = []
  @State private activeAccountId: string = ''
  @State private isLoaded: boolean = false

  aboutToAppear(): void {
    this.loadAccounts()
  }

  build() {
    Column() {
      SecondaryListScaffold({ bottomPadding: ThemeConstants.SPACE_MD }) {
        ListItem() {
          this.SectionHeader(AccountPageCoordinator.SECTION_ACCOUNT)
        }

        if (this.isLoaded && this.accounts.length === 0) {
          ListItem() {
            this.LoggedOutSection()
          }
        } else {
          ListItem() {
            this.AddAccountSection()
          }
        }

        if (this.isLoaded && this.accounts.length > 0) {
          ListItem() {
            this.SectionHeader(AccountPageCoordinator.ACCOUNT_LIST_HEADER)
          }
          .margin({ top: ThemeConstants.SPACE_MD })

          ListItem() {
            this.AccountListSection()
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.loadAccounts()
      }
    })
  }

  @Builder
  private SectionHeader(title: ResourceStr) {
    SharedSectionHeader({ title: title })
  }

  @Builder
  private SettingsDivider() {
    SharedListDivider()
  }

  @Builder
  private LoggedOutSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AccountPageCoordinator.LOGIN_TITLE,
        subtitle: AccountPageCoordinator.LOGIN_SUBTITLE,
        action: () => {
          this.startAddAccount()
        }
      })
    }
  }

  @Builder
  private AddAccountSection() {
    GroupedListSection() {
      ConciseListRow({
        title: AccountPageCoordinator.ADD_ANOTHER_ACCOUNT_TITLE,
        subtitle: AccountPageCoordinator.LOGIN_SUBTITLE,
        action: () => {
          this.startAddAccount()
        }
      })
    }
  }

  @Builder
  private AccountListSection() {
    GroupedListSection() {
      ForEach(this.accounts, (record: AccountRecord, index: number) => {
        Column() {
          Row() {
            Column({ space: ThemeConstants.SPACE_XS }) {
              Text(record.username)
                .fontSize(ThemeConstants.FONT_SIZE_LIST_ITEM)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.activeAccountId === record.id) {
                Text(AccountPageCoordinator.ACCOUNT_ACTIVE_LABEL)
                  .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                  .fontColor($r('sys.color.font_secondary'))
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (this.activeAccountId !== record.id) {
              Text(AccountPageCoordinator.SWITCH_LABEL)
                .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
                .fontColor($r('sys.color.font_secondary'))
                .padding(ThemeConstants.SPACE_SM)
                .onClick(() => {
                  this.switchAccount(record)
                })
            }

            Text(AccountPageCoordinator.REMOVE_LABEL)
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(Color.Red)
              .padding(ThemeConstants.SPACE_SM)
              .onClick(() => {
                this.confirmRemoveAccount(record)
              })
          }
          .width('100%')
          .padding({
            left: ThemeConstants.SPACE_LG,
            right: ThemeConstants.SPACE_LG,
            top: ThemeConstants.SPACE_SM,
            bottom: ThemeConstants.SPACE_SM
          })

          if (index < this.accounts.length - 1) {
            this.SettingsDivider()
          }
        }
      }, (record: AccountRecord) => record.id)
    }
  }

  private startAddAccount(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountSessionCoordinator.prepareAddAccount(context)
      .then(() => {
        console.info('AccountManagementPage: pending add account navigation')
        this.ns.pushPathByName('V2exNativeLogin', null)
      })
      .catch((error: Error) => {
        console.error('prepareAddAccount failed: ' + error.message)
      })
  }

  private switchAccount(record: AccountRecord): void {
    if (this.activeAccountId === record.id) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountSessionCoordinator.switchToAccount(context, record)
      .then(() => {
        console.info('AccountManagementPage: switched account id=' + record.id + ' username=' + record.username)
        this.loadAccounts()
      })
      .catch((error: Error) => {
        console.error('switchToAccount failed: ' + error.message)
      })
  }

  private confirmRemoveAccount(record: AccountRecord): void {
    this.getUIContext().showAlertDialog({
      title: AccountPageCoordinator.REMOVE_ACCOUNT_TITLE,
      message: AccountPageCoordinator.removeAccountMessage(record.username),
      primaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_CANCEL, 'Cancel'), action: () => {
        }
      },
      secondaryButton: {
        value: AppStrings.text(AppStrings.R_COMMON_REMOVE, 'Remove'),
        fontColor: Color.Red,
        action: () => {
          this.performRemoveAccount(record.id)
        }
      }
    })
  }

  private performRemoveAccount(id: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountSessionCoordinator.removeAccount(context, id)
      .then(() => {
        console.info('AccountManagementPage: removed account id=' + id)
        this.loadAccounts()
      })
      .catch((error: Error) => {
        console.error('removeAccount failed: ' + error.message)
      })
  }

  private loadAccounts(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    AccountStore.migrateFromSingletonIfNeeded(context)
      .then(() => AccountStore.restoreActiveId(context))
      .then(() => AccountStore.getAll(context))
      .then((records: AccountRecord[]) => {
        this.accounts = records
        this.activeAccountId = AccountStore.getActiveId()
        this.isLoaded = true
      })
      .catch((error: Error) => {
        console.error('load account management failed: ' + error.message)
        this.accounts = []
        this.activeAccountId = AccountStore.getActiveId()
        this.isLoaded = true
      })
  }
}
