import { common } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import type { BackupCollectionsSection } from '../backup/BackupTypes'
import { LocalDataStore } from '../storage/LocalDataStore'
import { connectUserMarks } from '../state/UserMarkState'
import { LocalDataPublisher } from './LocalDataPublisher'
import { withPreferencesStore } from './SettingsStorage'
import { STORE_NAME_COLLECTIONS } from './SettingsStores'

export interface UserMarkLabel {
  id: string
  name: string
  color: string
  sortOrder: number
  createdAt: number
  updatedAt: number
}

export interface UserMarkAssignment {
  usernameKey: string
  username: string
  labelId: string
  assignedAt: number
  updatedAt: number
}

export interface UserMarkSnapshot {
  labels: UserMarkLabel[]
  assignments: UserMarkAssignment[]
  displayLimit: number
  updatedAt: number
}

const STORE_NAME: string = STORE_NAME_COLLECTIONS
const KEY_DISPLAY_LIMIT: string = 'userMarkDisplayLimit'

const SQL_SELECT_LABELS: string = 'SELECT label_id, name, color, sort_order, created_at, updated_at FROM user_mark_labels ORDER BY sort_order ASC, updated_at DESC'
const SQL_SELECT_ASSIGNMENTS: string = 'SELECT username_key, username, label_id, assigned_at, updated_at FROM user_mark_assignments ORDER BY username_key ASC, assigned_at ASC, label_id ASC'
const SQL_SELECT_MAX_SORT_ORDER: string = 'SELECT MAX(sort_order) AS max_sort_order FROM user_mark_labels'
const SQL_UPSERT_LABEL: string = 'INSERT OR REPLACE INTO user_mark_labels (label_id, name, color, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)'
const SQL_UPSERT_ASSIGNMENT: string = 'INSERT OR REPLACE INTO user_mark_assignments (username_key, username, label_id, assigned_at, updated_at) VALUES (?, ?, ?, ?, ?)'
const SQL_DELETE_ASSIGNMENT: string = 'DELETE FROM user_mark_assignments WHERE username_key = ? AND label_id = ?'
const SQL_CLEAR_LABELS: string = 'DELETE FROM user_mark_labels'
const SQL_CLEAR_ASSIGNMENTS: string = 'DELETE FROM user_mark_assignments'

export class UserMarkSettings {
  static readonly DEFAULT_DISPLAY_LIMIT: number = 2
  static readonly MIN_DISPLAY_LIMIT: number = 1
  static readonly MAX_DISPLAY_LIMIT: number = 5
  static readonly DEFAULT_COLOR: string = '#6C8AE4'

  static async load(context: common.UIAbilityContext): Promise<UserMarkSnapshot> {
    const store = await LocalDataStore.open(context)
    const labels = UserMarkSettings.readLabelsResult(await store.querySql(SQL_SELECT_LABELS))
    const assignments = UserMarkSettings.readAssignmentsResult(await store.querySql(SQL_SELECT_ASSIGNMENTS))
    const displayLimit = await UserMarkSettings.loadDisplayLimit(context)
    const snapshot: UserMarkSnapshot = {
      labels: labels,
      assignments: assignments,
      displayLimit: displayLimit,
      updatedAt: UserMarkSettings.snapshotUpdatedAt(labels, assignments)
    }
    UserMarkSettings.apply(snapshot)
    return snapshot
  }

  static async loadLabels(context: common.UIAbilityContext): Promise<UserMarkLabel[]> {
    const store = await LocalDataStore.open(context)
    return UserMarkSettings.readLabelsResult(await store.querySql(SQL_SELECT_LABELS))
  }

  static async loadAssignments(context: common.UIAbilityContext): Promise<UserMarkAssignment[]> {
    const store = await LocalDataStore.open(context)
    return UserMarkSettings.readAssignmentsResult(await store.querySql(SQL_SELECT_ASSIGNMENTS))
  }

  static async createLabelAndAssign(
    context: common.UIAbilityContext,
    username: string,
    name: string,
    color: string
  ): Promise<UserMarkSnapshot> {
    const cleanUsername = (username || '').trim()
    const usernameKey = UserMarkSettings.normalizeUsernameKey(cleanUsername)
    const cleanName = UserMarkSettings.normalizeLabelName(name)
    if (!usernameKey || !cleanName) {
      return await UserMarkSettings.load(context)
    }
    const store = await LocalDataStore.open(context)
    const labels = UserMarkSettings.readLabelsResult(await store.querySql(SQL_SELECT_LABELS))
    let label = UserMarkSettings.findLabelByName(labels, cleanName)
    const now = Date.now()
    if (!label) {
      const sortOrder = await UserMarkSettings.nextSortOrder(store)
      label = {
        id: UserMarkSettings.createLabelId(now, sortOrder),
        name: cleanName,
        color: UserMarkSettings.normalizeColor(color),
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now
      }
      await UserMarkSettings.upsertLabel(store, label)
    }
    await UserMarkSettings.upsertAssignment(store, {
      usernameKey: usernameKey,
      username: cleanUsername,
      labelId: label.id,
      assignedAt: now,
      updatedAt: now
    })
    LocalDataPublisher.touchLocalData()
    return await UserMarkSettings.load(context)
  }

  static async assignLabel(
    context: common.UIAbilityContext,
    username: string,
    labelId: string
  ): Promise<UserMarkSnapshot> {
    const cleanUsername = (username || '').trim()
    const usernameKey = UserMarkSettings.normalizeUsernameKey(cleanUsername)
    const cleanLabelId = (labelId || '').trim()
    if (!usernameKey || !cleanLabelId) {
      return await UserMarkSettings.load(context)
    }
    const now = Date.now()
    const store = await LocalDataStore.open(context)
    await UserMarkSettings.upsertAssignment(store, {
      usernameKey: usernameKey,
      username: cleanUsername,
      labelId: cleanLabelId,
      assignedAt: now,
      updatedAt: now
    })
    LocalDataPublisher.touchLocalData()
    return await UserMarkSettings.load(context)
  }

  static async unassignLabel(
    context: common.UIAbilityContext,
    username: string,
    labelId: string
  ): Promise<UserMarkSnapshot> {
    const usernameKey = UserMarkSettings.normalizeUsernameKey(username)
    const cleanLabelId = (labelId || '').trim()
    if (!usernameKey || !cleanLabelId) {
      return await UserMarkSettings.load(context)
    }
    const store = await LocalDataStore.open(context)
    const args: relationalStore.ValueType[] = [usernameKey, cleanLabelId]
    await store.executeSql(SQL_DELETE_ASSIGNMENT, args)
    LocalDataPublisher.touchLocalData()
    return await UserMarkSettings.load(context)
  }

  static async saveDisplayLimit(context: common.UIAbilityContext, value: number): Promise<UserMarkSnapshot> {
    const next = UserMarkSettings.clampDisplayLimit(value)
    await withPreferencesStore<void>(context, STORE_NAME, (store) => {
      store.putSync(KEY_DISPLAY_LIMIT, next)
      store.flushSync()
    })
    const state = connectUserMarks()
    state.displayLimit = next
    state.updatedAt = UserMarkSettings.nextUpdatedAt(state.updatedAt)
    LocalDataPublisher.touchLocalData()
    return await UserMarkSettings.load(context)
  }

  static async restoreBackup(context: common.UIAbilityContext, section: BackupCollectionsSection): Promise<void> {
    const store = await LocalDataStore.open(context)
    await store.executeSql(SQL_CLEAR_ASSIGNMENTS)
    await store.executeSql(SQL_CLEAR_LABELS)
    const labels = (section.userMarkLabels || []) as UserMarkLabel[]
    for (let i = 0; i < labels.length; i++) {
      await UserMarkSettings.upsertLabel(store, UserMarkSettings.normalizeBackupLabel(labels[i]))
    }
    const assignments = (section.userMarkAssignments || []) as UserMarkAssignment[]
    for (let i = 0; i < assignments.length; i++) {
      const assignment = UserMarkSettings.normalizeBackupAssignment(assignments[i])
      if (assignment.usernameKey && assignment.labelId) {
        await UserMarkSettings.upsertAssignment(store, assignment)
      }
    }
    await withPreferencesStore<void>(context, STORE_NAME, (prefs) => {
      prefs.putSync(KEY_DISPLAY_LIMIT, UserMarkSettings.clampDisplayLimit(section.userMarkDisplayLimit || UserMarkSettings.DEFAULT_DISPLAY_LIMIT))
      prefs.flushSync()
    })
    LocalDataPublisher.touchLocalData()
    await UserMarkSettings.load(context)
  }

  static async clearAll(context: common.UIAbilityContext): Promise<void> {
    const store = await LocalDataStore.open(context)
    await store.executeSql(SQL_CLEAR_ASSIGNMENTS)
    await store.executeSql(SQL_CLEAR_LABELS)
    await withPreferencesStore<void>(context, STORE_NAME, (prefs) => {
      prefs.deleteSync(KEY_DISPLAY_LIMIT)
      prefs.flushSync()
    })
    const snapshot: UserMarkSnapshot = {
      labels: [],
      assignments: [],
      displayLimit: UserMarkSettings.DEFAULT_DISPLAY_LIMIT,
      updatedAt: Date.now()
    }
    UserMarkSettings.apply(snapshot)
    LocalDataPublisher.touchLocalData()
  }

  static apply(snapshot: UserMarkSnapshot): void {
    const state = connectUserMarks()
    state.labelsJson = JSON.stringify(snapshot.labels)
    state.assignmentsJson = JSON.stringify(snapshot.assignments)
    state.displayLimit = UserMarkSettings.clampDisplayLimit(snapshot.displayLimit)
    state.updatedAt = UserMarkSettings.nextUpdatedAt(Math.max(state.updatedAt, snapshot.updatedAt))
  }

  static normalizeUsernameKey(username: string): string {
    return (username || '').trim().toLowerCase()
  }

  static defaultColors(): string[] {
    return ['#6C8AE4', '#3BA272', '#D48265', '#9A60B4', '#E6A23C', '#D94F70']
  }

  static parseLabels(labelsJson: string): UserMarkLabel[] {
    try {
      const parsed = JSON.parse(labelsJson || '[]') as UserMarkLabel[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const labels: UserMarkLabel[] = []
      for (let i = 0; i < parsed.length; i++) {
        const label = UserMarkSettings.normalizeBackupLabel(parsed[i])
        if (label.id && label.name) {
          labels.push(label)
        }
      }
      return labels
    } catch (_error) {
      return []
    }
  }

  static parseAssignments(assignmentsJson: string): UserMarkAssignment[] {
    try {
      const parsed = JSON.parse(assignmentsJson || '[]') as UserMarkAssignment[]
      if (!Array.isArray(parsed)) {
        return []
      }
      const assignments: UserMarkAssignment[] = []
      for (let i = 0; i < parsed.length; i++) {
        const assignment = UserMarkSettings.normalizeBackupAssignment(parsed[i])
        if (assignment.usernameKey && assignment.labelId) {
          assignments.push(assignment)
        }
      }
      return assignments
    } catch (_error) {
      return []
    }
  }

  static allLabelsForUsername(username: string, labelsJson: string, assignmentsJson: string): UserMarkLabel[] {
    const usernameKey = UserMarkSettings.normalizeUsernameKey(username)
    if (!usernameKey) {
      return []
    }
    const labels = UserMarkSettings.parseLabels(labelsJson)
    const assignments = UserMarkSettings.parseAssignments(assignmentsJson)
    const result: UserMarkLabel[] = []
    for (let i = 0; i < assignments.length; i++) {
      const assignment = assignments[i]
      if (assignment.usernameKey !== usernameKey) {
        continue
      }
      const label = UserMarkSettings.findLabelById(labels, assignment.labelId)
      if (label) {
        result.push(label)
      }
    }
    return result
  }

  static visibleLabelsForUsername(
    username: string,
    labelsJson: string,
    assignmentsJson: string,
    displayLimit: number
  ): UserMarkLabel[] {
    const all = UserMarkSettings.allLabelsForUsername(username, labelsJson, assignmentsJson)
    const limit = UserMarkSettings.clampDisplayLimit(displayLimit)
    return all.slice(0, Math.min(limit, all.length))
  }

  static overflowCountForUsername(
    username: string,
    labelsJson: string,
    assignmentsJson: string,
    displayLimit: number
  ): number {
    const all = UserMarkSettings.allLabelsForUsername(username, labelsJson, assignmentsJson)
    return Math.max(0, all.length - UserMarkSettings.clampDisplayLimit(displayLimit))
  }

  static isLabelAssignedToUsername(username: string, labelId: string, assignmentsJson: string): boolean {
    const usernameKey = UserMarkSettings.normalizeUsernameKey(username)
    const cleanLabelId = (labelId || '').trim()
    if (!usernameKey || !cleanLabelId) {
      return false
    }
    const assignments = UserMarkSettings.parseAssignments(assignmentsJson)
    for (let i = 0; i < assignments.length; i++) {
      if (assignments[i].usernameKey === usernameKey && assignments[i].labelId === cleanLabelId) {
        return true
      }
    }
    return false
  }

  static textColorForBackground(color: string): string {
    const clean = UserMarkSettings.normalizeColor(color)
    const red = UserMarkSettings.parseHexByte(clean, 1)
    const green = UserMarkSettings.parseHexByte(clean, 3)
    const blue = UserMarkSettings.parseHexByte(clean, 5)
    const luminance = red * 0.299 + green * 0.587 + blue * 0.114
    return luminance > 150 ? '#1F2328' : '#FFFFFF'
  }

  private static async loadDisplayLimit(context: common.UIAbilityContext): Promise<number> {
    return await withPreferencesStore<number>(context, STORE_NAME, (store) => {
      const raw = store.getSync(KEY_DISPLAY_LIMIT, UserMarkSettings.DEFAULT_DISPLAY_LIMIT)
      if (typeof raw === 'number') {
        return UserMarkSettings.clampDisplayLimit(raw)
      }
      if (typeof raw === 'string') {
        const parsed = Number.parseInt(raw, 10)
        return UserMarkSettings.clampDisplayLimit(Number.isNaN(parsed) ? UserMarkSettings.DEFAULT_DISPLAY_LIMIT : parsed)
      }
      return UserMarkSettings.DEFAULT_DISPLAY_LIMIT
    })
  }

  private static clampDisplayLimit(value: number): number {
    const next = Math.floor(value)
    if (Number.isNaN(next)) {
      return UserMarkSettings.DEFAULT_DISPLAY_LIMIT
    }
    return Math.min(UserMarkSettings.MAX_DISPLAY_LIMIT, Math.max(UserMarkSettings.MIN_DISPLAY_LIMIT, next))
  }

  private static normalizeLabelName(name: string): string {
    const clean = (name || '').trim()
    if (clean.length > 16) {
      return clean.slice(0, 16)
    }
    return clean
  }

  private static normalizeColor(color: string): string {
    const clean = (color || '').trim()
    if (/^#[0-9A-Fa-f]{6}$/.test(clean)) {
      return clean.toUpperCase()
    }
    return UserMarkSettings.DEFAULT_COLOR
  }

  private static normalizeBackupLabel(label: UserMarkLabel): UserMarkLabel {
    const now = Date.now()
    return {
      id: (label?.id || '').trim(),
      name: UserMarkSettings.normalizeLabelName(label?.name || ''),
      color: UserMarkSettings.normalizeColor(label?.color || ''),
      sortOrder: Math.max(0, Math.floor(label?.sortOrder || 0)),
      createdAt: Math.max(0, Math.floor(label?.createdAt || now)),
      updatedAt: Math.max(0, Math.floor(label?.updatedAt || now))
    }
  }

  private static normalizeBackupAssignment(assignment: UserMarkAssignment): UserMarkAssignment {
    const cleanUsername = (assignment?.username || '').trim()
    const usernameKey = UserMarkSettings.normalizeUsernameKey(assignment?.usernameKey || cleanUsername)
    const now = Date.now()
    return {
      usernameKey: usernameKey,
      username: cleanUsername || usernameKey,
      labelId: (assignment?.labelId || '').trim(),
      assignedAt: Math.max(0, Math.floor(assignment?.assignedAt || now)),
      updatedAt: Math.max(0, Math.floor(assignment?.updatedAt || now))
    }
  }

  private static readLabelsResult(resultSet: relationalStore.ResultSet): UserMarkLabel[] {
    const labels: UserMarkLabel[] = []
    try {
      const idIndex = resultSet.getColumnIndex('label_id')
      const nameIndex = resultSet.getColumnIndex('name')
      const colorIndex = resultSet.getColumnIndex('color')
      const sortIndex = resultSet.getColumnIndex('sort_order')
      const createdIndex = resultSet.getColumnIndex('created_at')
      const updatedIndex = resultSet.getColumnIndex('updated_at')
      while (resultSet.goToNextRow()) {
        const label: UserMarkLabel = {
          id: resultSet.getString(idIndex),
          name: resultSet.getString(nameIndex),
          color: resultSet.getString(colorIndex),
          sortOrder: resultSet.getLong(sortIndex),
          createdAt: resultSet.getLong(createdIndex),
          updatedAt: resultSet.getLong(updatedIndex)
        }
        if (label.id && label.name) {
          labels.push(label)
        }
      }
    } finally {
      resultSet.close()
    }
    return labels
  }

  private static readAssignmentsResult(resultSet: relationalStore.ResultSet): UserMarkAssignment[] {
    const assignments: UserMarkAssignment[] = []
    try {
      const usernameKeyIndex = resultSet.getColumnIndex('username_key')
      const usernameIndex = resultSet.getColumnIndex('username')
      const labelIdIndex = resultSet.getColumnIndex('label_id')
      const assignedAtIndex = resultSet.getColumnIndex('assigned_at')
      const updatedAtIndex = resultSet.getColumnIndex('updated_at')
      while (resultSet.goToNextRow()) {
        const assignment: UserMarkAssignment = {
          usernameKey: resultSet.getString(usernameKeyIndex),
          username: resultSet.getString(usernameIndex),
          labelId: resultSet.getString(labelIdIndex),
          assignedAt: resultSet.getLong(assignedAtIndex),
          updatedAt: resultSet.getLong(updatedAtIndex)
        }
        if (assignment.usernameKey && assignment.labelId) {
          assignments.push(assignment)
        }
      }
    } finally {
      resultSet.close()
    }
    return assignments
  }

  private static async upsertLabel(store: relationalStore.RdbStore, label: UserMarkLabel): Promise<void> {
    const clean = UserMarkSettings.normalizeBackupLabel(label)
    if (!clean.id || !clean.name) {
      return
    }
    const args: relationalStore.ValueType[] = [
      clean.id,
      clean.name,
      clean.color,
      clean.sortOrder,
      clean.createdAt,
      clean.updatedAt
    ]
    await store.executeSql(SQL_UPSERT_LABEL, args)
  }

  private static async upsertAssignment(store: relationalStore.RdbStore, assignment: UserMarkAssignment): Promise<void> {
    const clean = UserMarkSettings.normalizeBackupAssignment(assignment)
    if (!clean.usernameKey || !clean.labelId) {
      return
    }
    const args: relationalStore.ValueType[] = [
      clean.usernameKey,
      clean.username,
      clean.labelId,
      clean.assignedAt,
      clean.updatedAt
    ]
    await store.executeSql(SQL_UPSERT_ASSIGNMENT, args)
  }

  private static async nextSortOrder(store: relationalStore.RdbStore): Promise<number> {
    const resultSet = await store.querySql(SQL_SELECT_MAX_SORT_ORDER)
    try {
      if (!resultSet.goToNextRow() || resultSet.isColumnNull(resultSet.getColumnIndex('max_sort_order'))) {
        return 1
      }
      return Math.max(1, resultSet.getLong(resultSet.getColumnIndex('max_sort_order')) + 1)
    } finally {
      resultSet.close()
    }
  }

  private static findLabelByName(labels: UserMarkLabel[], name: string): UserMarkLabel | null {
    const key = (name || '').trim().toLowerCase()
    for (let i = 0; i < labels.length; i++) {
      if ((labels[i].name || '').trim().toLowerCase() === key) {
        return labels[i]
      }
    }
    return null
  }

  private static findLabelById(labels: UserMarkLabel[], id: string): UserMarkLabel | null {
    const key = (id || '').trim()
    for (let i = 0; i < labels.length; i++) {
      if (labels[i].id === key) {
        return labels[i]
      }
    }
    return null
  }

  private static createLabelId(now: number, sortOrder: number): string {
    return `user_mark_${now}_${sortOrder}`
  }

  private static snapshotUpdatedAt(labels: UserMarkLabel[], assignments: UserMarkAssignment[]): number {
    let updatedAt = 0
    for (let i = 0; i < labels.length; i++) {
      updatedAt = Math.max(updatedAt, labels[i].updatedAt)
    }
    for (let i = 0; i < assignments.length; i++) {
      updatedAt = Math.max(updatedAt, assignments[i].updatedAt)
    }
    return updatedAt
  }

  private static nextUpdatedAt(current: number): number {
    return Math.max(Date.now(), current + 1)
  }

  private static parseHexByte(value: string, start: number): number {
    const parsed = Number.parseInt(value.slice(start, start + 2), 16)
    return Number.isNaN(parsed) ? 0 : parsed
  }
}
