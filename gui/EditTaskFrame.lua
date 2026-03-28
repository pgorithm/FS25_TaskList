EditTaskFrame = {}
EditTaskFrame._params = nil

--- Row height in form layout (matches editTaskFormRow profile).
local EDIT_TASK_ROW_H = 52

local function trimWhitespace(str)
    return string.gsub(str or "", '^%s*(.-)%s*$', '%1')
end

--- Match TextInputElement / savegame limits (UTF-8 aware when engine helpers exist).
local function limitTaskDetailLength(str, maxLen)
    str = trimWhitespace(str)
    if str == "" then
        return ""
    end
    if type(utf8Strlen) == "function" and type(utf8Substr) == "function" then
        if utf8Strlen(str) > maxLen then
            return utf8Substr(str, 0, maxLen)
        end
        return str
    end
    if string.len(str) > maxLen then
        return string.sub(str, 1, maxLen)
    end
    return str
end

local EditTaskFrame_mt = Class(EditTaskFrame, MessageDialog)

--- @param elem GuiElement|nil
local function editTaskRowVisible(elem)
    if elem == nil then
        return false
    end
    if elem.getIsVisible ~= nil then
        return elem:getIsVisible()
    end
    return elem.isVisible ~= false
end

--- @param elem GuiElement|nil
--- @param y number  Y offset in pixels (negative stacks downward in this dialog)
local function editTaskSetRowY(elem, y)
    if elem == nil or elem.setPosition == nil then
        return
    end
    elem:setPosition("0px", string.format("%dpx", y))
end

function EditTaskFrame:_optionCallbacksSuppressed()
    return (self._optionCallbackSuppressDepth or 0) > 0
end

--- Batch MultiTextOption setState/setTexts without treating engine-spurious onClick as user input.
function EditTaskFrame:withSuppressedOptionCallbacks(fn)
    self._optionCallbackSuppressDepth = (self._optionCallbackSuppressDepth or 0) + 1
    fn()
    self._optionCallbackSuppressDepth = math.max(0, (self._optionCallbackSuppressDepth or 1) - 1)
end

function EditTaskFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or EditTaskFrame_mt)
    self.i18n = g_i18n
    return self
end

--- @param reopenManageTasks boolean|nil If true, show manageTasksFrame again after this dialog closes (avoids stacking two MessageDialogs).
function EditTaskFrame.open(groupId, group, task, isEdit, reopenManageTasks)
    local working = task
    if isEdit then
        working = Task.new()
        working:copyValuesFromTask(task, true)
    end
    EditTaskFrame._params = {
        groupId = groupId,
        group = group,
        task = working,
        isEdit = isEdit,
        reopenManageTasks = reopenManageTasks == true
    }
    g_gui:showDialog("editTaskFrame")
end

function EditTaskFrame:onCreate()
    EditTaskFrame:superClass().onCreate(self)
end

function EditTaskFrame:onGuiSetupFinished()
    EditTaskFrame:superClass().onGuiSetupFinished(self)
    self._standardRows = {
        self.standardDetailRow,
        self.standardEffortRow,
        self.standardPriorityRow,
        self.standardRecurToggleRow,
        self.recurModeRow,
        self.recurNRow,
        self.startPeriodRow,
        self.periodRow
    }
    self._foodRows = { self.foodTypeRow, self.foodLevelRow }
    self._conditionRows = { self.conditionTypeRow, self.conditionEvalRow, self.conditionLevelRow }
    self._productionRows = {
        self.productionPickRow,
        self.productionIoRow,
        self.productionFillRow,
        self.productionEvalRow,
        self.productionLevelRow
    }
end

--- Stack visible rows inside a section; returns next Y cursor (negative) inside that section.
function EditTaskFrame:layoutRowStack(rows, startY)
    local y = startY
    for _, row in ipairs(rows) do
        if editTaskRowVisible(row) then
            editTaskSetRowY(row, y)
            y = y - EDIT_TASK_ROW_H
        end
    end
    return y
end

--- Position a block and stack its rows; returns next Y cursor relative to the same parent as the block.
function EditTaskFrame:layoutBlockAtY(block, innerRows, yCursor)
    if not editTaskRowVisible(block) then
        return yCursor
    end
    editTaskSetRowY(block, yCursor)
    local inner = 0
    for _, row in ipairs(innerRows) do
        if editTaskRowVisible(row) then
            editTaskSetRowY(row, inner)
            inner = inner - EDIT_TASK_ROW_H
        end
    end
    return yCursor + inner
end

--- Repack form rows so hidden fields leave no empty gaps.
function EditTaskFrame:relayoutForm()
    if self.formRoot == nil then
        return
    end
    if self._standardRows == nil then
        self._standardRows = {
            self.standardDetailRow,
            self.standardEffortRow,
            self.standardPriorityRow,
            self.standardRecurToggleRow,
            self.recurModeRow,
            self.recurNRow,
            self.startPeriodRow,
            self.periodRow
        }
        self._foodRows = { self.foodTypeRow, self.foodLevelRow }
        self._conditionRows = { self.conditionTypeRow, self.conditionEvalRow, self.conditionLevelRow }
        self._productionRows = {
            self.productionPickRow,
            self.productionIoRow,
            self.productionFillRow,
            self.productionEvalRow,
            self.productionLevelRow
        }
    end

    local sectionStart = 0
    if editTaskRowVisible(self.taskTypeRow) then
        editTaskSetRowY(self.taskTypeRow, 0)
        sectionStart = -EDIT_TASK_ROW_H
    end

    if editTaskRowVisible(self.standardSection) then
        self.standardSection:setPosition("0px", string.format("%dpx", sectionStart))
        self:layoutRowStack(self._standardRows or {}, 0)
    elseif editTaskRowVisible(self.linkedSection) then
        self.linkedSection:setPosition("0px", string.format("%dpx", sectionStart))
        local y2 = 0
        if editTaskRowVisible(self.husbandryPickRow) then
            editTaskSetRowY(self.husbandryPickRow, y2)
            y2 = y2 - EDIT_TASK_ROW_H
        end
        if editTaskRowVisible(self.foodBlock) then
            y2 = self:layoutBlockAtY(self.foodBlock, self._foodRows or {}, y2)
        elseif editTaskRowVisible(self.conditionBlock) then
            y2 = self:layoutBlockAtY(self.conditionBlock, self._conditionRows or {}, y2)
        elseif editTaskRowVisible(self.productionBlock) then
            y2 = self:layoutBlockAtY(self.productionBlock, self._productionRows or {}, y2)
        end
    end
end

function EditTaskFrame:linkedObjectCounts()
    local husbandryCount = 0
    for _ in pairs(g_currentMission.taskList:getHusbandries()) do
        husbandryCount = husbandryCount + 1
    end
    local productionCount = 0
    for _ in pairs(g_currentMission.taskList:getProductions()) do
        productionCount = productionCount + 1
    end
    return husbandryCount, productionCount, husbandryCount + productionCount
end

function EditTaskFrame:shouldShowTaskType()
    local _, _, total = self:linkedObjectCounts()
    return self.group.type ~= TaskGroup.GROUP_TYPE.Template and total > 0
end

function EditTaskFrame:monthNameTexts()
    return {
        g_i18n:getText("ui_month1"),
        g_i18n:getText("ui_month2"),
        g_i18n:getText("ui_month3"),
        g_i18n:getText("ui_month4"),
        g_i18n:getText("ui_month5"),
        g_i18n:getText("ui_month6"),
        g_i18n:getText("ui_month7"),
        g_i18n:getText("ui_month8"),
        g_i18n:getText("ui_month9"),
        g_i18n:getText("ui_month10"),
        g_i18n:getText("ui_month11"),
        g_i18n:getText("ui_month12")
    }
end

function EditTaskFrame:buildLevelOptionTexts(capacity)
    return {
        g_i18n:getText("ui_task_level_empty"),
        string.format("10%% (%s)", g_i18n:formatVolume(capacity * 0.10, 0)),
        string.format("20%% (%s)", g_i18n:formatVolume(capacity * 0.20, 0)),
        string.format("30%% (%s)", g_i18n:formatVolume(capacity * 0.30, 0)),
        string.format("40%% (%s)", g_i18n:formatVolume(capacity * 0.40, 0)),
        string.format("50%% (%s)", g_i18n:formatVolume(capacity * 0.50, 0)),
        string.format("60%% (%s)", g_i18n:formatVolume(capacity * 0.60, 0)),
        string.format("70%% (%s)", g_i18n:formatVolume(capacity * 0.70, 0)),
        string.format("80%% (%s)", g_i18n:formatVolume(capacity * 0.80, 0)),
        string.format("90%% (%s)", g_i18n:formatVolume(capacity * 0.90, 0))
    }
end

function EditTaskFrame:levelStateForStoredLevel(level, capacity)
    if capacity == nil or capacity <= 0 then
        return 1
    end
    if level == 0 then
        return 1
    end
    local idx = math.floor((level / capacity) * 10) + 1
    if idx < 1 then idx = 1 end
    if idx > 10 then idx = 10 end
    return idx
end

function EditTaskFrame:applyLevelFromState(idx, capacity)
    if idx <= 1 or capacity == nil or capacity <= 0 then
        return 0
    end
    return (idx - 1) * 0.10 * capacity
end

function EditTaskFrame:populateTaskTypeOption()
    self._taskTypeOrder = {}
    local options = {}
    table.insert(options, g_i18n:getText("ui_type_standard"))
    table.insert(self._taskTypeOrder, Task.TASK_TYPE.Standard)

    local husbandryCount = 0
    for _ in pairs(g_currentMission.taskList:getHusbandries()) do husbandryCount = husbandryCount + 1 end
    if husbandryCount > 0 then
        table.insert(options, g_i18n:getText("ui_type_husbandry_food"))
        table.insert(self._taskTypeOrder, Task.TASK_TYPE.HusbandryFood)
        table.insert(options, g_i18n:getText("ui_type_husbandry_conditions"))
        table.insert(self._taskTypeOrder, Task.TASK_TYPE.HusbandryConditions)
    end

    local productionCount = 0
    for _ in pairs(g_currentMission.taskList:getProductions()) do productionCount = productionCount + 1 end
    if productionCount > 0 then
        table.insert(options, g_i18n:getText("ui_type_production"))
        table.insert(self._taskTypeOrder, Task.TASK_TYPE.Production)
    end

    self.taskTypeOption:setTexts(options)
    local state = 1
    for i, t in ipairs(self._taskTypeOrder) do
        if t == self.task.type then
            state = i
            break
        end
    end
    self.taskTypeOption:setState(state, false)
end

function EditTaskFrame:populateHusbandryOptions()
    self._husbandryList = {}
    self._husbandryLookup = {}
    local options = {}
    for _, husbandry in pairs(g_currentMission.taskList:getHusbandries()) do
        if self.task.type == Task.TASK_TYPE.HusbandryConditions then
            local conditionCount = 0
            for _ in pairs(husbandry.conditionInfos) do conditionCount = conditionCount + 1 end
            if conditionCount == 0 then
                -- skip husbandries with no conditions
            else
                table.insert(options, husbandry.name)
                table.insert(self._husbandryList, husbandry)
                self._husbandryLookup[husbandry.name] = husbandry
            end
        else
            table.insert(options, husbandry.name)
            table.insert(self._husbandryList, husbandry)
            self._husbandryLookup[husbandry.name] = husbandry
        end
    end
    self.husbandryOption:setTexts(options)
    local default = 1
    for i, h in ipairs(self._husbandryList) do
        if self.task:getObjectId() == h.id then
            default = i
            break
        end
    end
    if #options == 0 then
        self.husbandryOption:setState(1, false)
        return
    end
    self.husbandryOption:setState(default, false)
    local h = self._husbandryList[default]
    if h ~= nil then
        self.task.objectId = h.id
    end
end

function EditTaskFrame:populateFoodOptions()
    local husbandry = g_currentMission.taskList:getHusbandries()[self.task:getObjectId()]
    if husbandry == nil then
        self.foodTypeOption:setTexts({})
        self.foodLevelOption:setTexts({})
        return
    end
    local options = { g_i18n:getText("ui_husbandry_food_total") }
    self._foodKeys = { Task.TOTAL_FOOD_KEY }
    for _, foodInfo in pairs(husbandry.keys) do
        table.insert(options, foodInfo.title)
        table.insert(self._foodKeys, foodInfo.key)
    end
    self.foodTypeOption:setTexts(options)
    local fstate = 1
    for i, key in ipairs(self._foodKeys) do
        if self.task.husbandryFood == key then
            fstate = i
            break
        end
    end
    self.foodTypeOption:setState(fstate, false)

    local levelTexts = self:buildLevelOptionTexts(husbandry.foodCapacity)
    self.foodLevelOption:setTexts(levelTexts)
    self.foodLevelOption:setState(self:levelStateForStoredLevel(self.task.husbandryLevel, husbandry.foodCapacity), false)
end

function EditTaskFrame:populateConditionOptions()
    local husbandry = g_currentMission.taskList:getHusbandries()[self.task:getObjectId()]
    if husbandry == nil then
        self.conditionTypeOption:setTexts({})
        self.conditionLevelOption:setTexts({})
        return
    end
    local options = {}
    self._conditionKeys = {}
    for _, conditionInfo in pairs(husbandry.conditionInfos) do
        table.insert(options, conditionInfo.title)
        table.insert(self._conditionKeys, conditionInfo.key)
    end
    self.conditionTypeOption:setTexts(options)
    local cstate = 1
    for i, key in ipairs(self._conditionKeys) do
        if self.task.husbandryCondition == key then
            cstate = i
            break
        end
    end
    if #options > 0 then
        self.conditionTypeOption:setState(cstate, false)
        local key = self._conditionKeys[cstate]
        if key ~= nil then
            self.task.husbandryCondition = key
        end
    end

    local evalTexts = {
        g_i18n:getText("ui_task_condition_evaluator_less_than"),
        g_i18n:getText("ui_task_condition_evaluator_greater_than")
    }
    self.conditionEvalOption:setTexts(evalTexts)
    self.conditionEvalOption:setState(self.task.evaluator, false)

    local conditionInfo = husbandry.conditionInfos[self.task.husbandryCondition]
    if conditionInfo == nil then
        self.conditionLevelOption:setTexts(self:buildLevelOptionTexts(1))
        self.conditionLevelOption:setState(1, false)
        return
    end
    self.conditionLevelOption:setTexts(self:buildLevelOptionTexts(conditionInfo.capacity))
    self.conditionLevelOption:setState(self:levelStateForStoredLevel(self.task.husbandryLevel, conditionInfo.capacity), false)
end

function EditTaskFrame:populateProductionOptions()
    self._productionList = {}
    local options = {}
    for _, production in pairs(g_currentMission.taskList:getProductions()) do
        table.insert(options, production.name)
        table.insert(self._productionList, production)
    end
    self.productionOption:setTexts(options)
    local pstate = 1
    for i, p in ipairs(self._productionList) do
        if self.task:getObjectId() == p.id then
            pstate = i
            break
        end
    end
    if #options > 0 then
        self.productionOption:setState(pstate, false)
        local p = self._productionList[pstate]
        if p ~= nil then
            self.task.objectId = p.id
        end
    end

    local ioTexts = {
        g_i18n:getText("ui_task_production_input"),
        g_i18n:getText("ui_task_production_output")
    }
    self.productionIoOption:setTexts(ioTexts)
    self.productionIoOption:setState(self.task.productionType, false)

    self:populateProductionFillAndLevel()
end

function EditTaskFrame:populateProductionFillAndLevel()
    local production = g_currentMission.taskList:getProductions()[self.task:getObjectId()]
    if production == nil then
        self.productionFillOption:setTexts({})
        self.productionLevelOption:setTexts({})
        return
    end
    local fillTypes = production.inputs
    if self.task.productionType == Task.PRODUCTION_TYPE.OUTPUT then
        fillTypes = production.outputs
    end
    local options = {}
    self._fillKeys = {}
    for _, fillInfo in pairs(fillTypes) do
        table.insert(options, fillInfo.title)
        table.insert(self._fillKeys, fillInfo.key)
    end
    self.productionFillOption:setTexts(options)
    local fstate = 1
    for i, key in ipairs(self._fillKeys) do
        if self.task.productionFillType == key then
            fstate = i
            break
        end
    end
    if #options > 0 then
        self.productionFillOption:setState(fstate, false)
        local key = self._fillKeys[fstate]
        if key ~= nil then
            self.task.productionFillType = key
        end
    end

    local evalTexts = {
        g_i18n:getText("ui_task_condition_evaluator_less_than"),
        g_i18n:getText("ui_task_condition_evaluator_greater_than")
    }
    self.productionEvalOption:setTexts(evalTexts)
    self.productionEvalOption:setState(self.task.evaluator, false)

    local fillInfo = nil
    if self.task.productionType == Task.PRODUCTION_TYPE.INPUT then
        fillInfo = production.inputs[self.task.productionFillType]
    else
        fillInfo = production.outputs[self.task.productionFillType]
    end
    if fillInfo == nil then
        self.productionLevelOption:setTexts(self:buildLevelOptionTexts(1))
        self.productionLevelOption:setState(1, false)
        return
    end
    self.productionLevelOption:setTexts(self:buildLevelOptionTexts(fillInfo.capacity))
    self.productionLevelOption:setState(self:levelStateForStoredLevel(self.task.productionLevel, fillInfo.capacity), false)
end

function EditTaskFrame:populateRecurNOption()
    local mode = self.recurModeOption:getState()
    local texts = {}
    self._recurNValues = {}
    if mode == Task.RECUR_MODE.EVERY_N_MONTHS then
        self.recurNLabel:setText(g_i18n:getText("ui_set_task_n_months"))
        for v = 1, 12 do
            table.insert(texts, tostring(v))
            table.insert(self._recurNValues, v)
        end
        table.insert(texts, "24")
        table.insert(self._recurNValues, 24)
        table.insert(texts, "36")
        table.insert(self._recurNValues, 36)
    elseif mode == Task.RECUR_MODE.EVERY_N_DAYS then
        self.recurNLabel:setText(g_i18n:getText("ui_set_task_n_days"))
        for v = 1, 12 do
            table.insert(texts, tostring(v))
            table.insert(self._recurNValues, v)
        end
    else
        self.recurNOption:setTexts({ "-" })
        self._recurNValues = {}
        self.recurNOption:setState(1, false)
        return
    end
    self.recurNOption:setTexts(texts)
    local want = self.task.n
    if want == 0 then want = 1 end
    local state = 1
    for i, n in ipairs(self._recurNValues) do
        if n == want then
            state = i
            break
        end
    end
    self.recurNOption:setState(state, false)
end

function EditTaskFrame:syncStandardWidgetsFromTask()
    self:setTaskDetailInputText(self.task.detail or "")

    local effortTexts = { "1", "2", "3", "4", "5" }
    self.effortOption:setTexts(effortTexts)
    self.effortOption:setState(math.max(1, math.min(5, self.task.effort or 1)), false)

    local priTexts = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" }
    self.priorityOption:setTexts(priTexts)
    self.priorityOption:setState(math.max(1, math.min(10, self.task.priority or 1)), false)

    local yn = { g_i18n:getText("ui_yes"), g_i18n:getText("ui_no") }
    self.shouldRecurOption:setTexts(yn)
    self.shouldRecurOption:setState(self.task.shouldRecur and 1 or 2, false)

    local recurTexts = {
        g_i18n:getText("ui_set_task_recur_mode_monthly"),
        g_i18n:getText("ui_task_due_daily"),
        g_i18n:getText("ui_set_task_recur_mode_n_months"),
        g_i18n:getText("ui_set_task_recur_mode_n_days")
    }
    self.recurModeOption:setTexts(recurTexts)
    local rm = self.task.recurMode
    if rm == nil or rm == Task.RECUR_MODE.NONE then
        rm = Task.RECUR_MODE.MONTHLY
    end
    self.recurModeOption:setState(rm, false)

    self:populateRecurNOption()

    local months = self:monthNameTexts()
    self.startPeriodOption:setTexts(months)
    local startDef = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
    if self.task.nextN ~= 0 then
        startDef = TaskListUtils.convertPeriodToMonthNumber(self.task.nextN)
    end
    self.startPeriodOption:setState(startDef, false)

    self.periodOption:setTexts(months)
    local perDef = TaskListUtils.convertPeriodToMonthNumber(g_currentMission.environment.currentPeriod)
    if self.task.period ~= 1 then
        perDef = TaskListUtils.convertPeriodToMonthNumber(self.task.period)
    end
    self.periodOption:setState(perDef, false)
end

function EditTaskFrame:populateLinkedForCurrentType()
    local t = self.task.type
    if t == Task.TASK_TYPE.HusbandryFood or t == Task.TASK_TYPE.HusbandryConditions then
        self:populateHusbandryOptions()
    end
    if t == Task.TASK_TYPE.HusbandryFood then
        self:populateFoodOptions()
    elseif t == Task.TASK_TYPE.HusbandryConditions then
        self:populateConditionOptions()
    elseif t == Task.TASK_TYPE.Production then
        self:populateProductionOptions()
    end
end

function EditTaskFrame:updateVisibility()
    local showType = self:shouldShowTaskType()
    self.taskTypeRow:setVisible(showType)
    if not showType then
        self.task.type = Task.TASK_TYPE.Standard
    end
    if self.task.type ~= Task.TASK_TYPE.Standard
        and self.task.type ~= Task.TASK_TYPE.HusbandryFood
        and self.task.type ~= Task.TASK_TYPE.HusbandryConditions
        and self.task.type ~= Task.TASK_TYPE.Production then
        self.task.type = Task.TASK_TYPE.Standard
    end

    local std = self.task.type == Task.TASK_TYPE.Standard
    self.standardSection:setVisible(std)
    self.linkedSection:setVisible(not std)

    local food = self.task.type == Task.TASK_TYPE.HusbandryFood
    local cond = self.task.type == Task.TASK_TYPE.HusbandryConditions
    local prod = self.task.type == Task.TASK_TYPE.Production

    self.husbandryPickRow:setVisible(food or cond)
    self.foodBlock:setVisible(food)
    self.conditionBlock:setVisible(cond)
    self.productionBlock:setVisible(prod)

    local recurOn = std and self.shouldRecurOption:getState() == 1
    local mode = self.recurModeOption:getState()
    local needN = std and recurOn and (mode == Task.RECUR_MODE.EVERY_N_MONTHS or mode == Task.RECUR_MODE.EVERY_N_DAYS)
    local needStart = std and recurOn and mode == Task.RECUR_MODE.EVERY_N_MONTHS
    local needPeriod = std and ((not recurOn) or mode == Task.RECUR_MODE.MONTHLY)

    self.recurModeRow:setVisible(std and recurOn)
    self.recurNRow:setVisible(needN)
    self.startPeriodRow:setVisible(needStart)
    self.periodRow:setVisible(needPeriod)

    if self.recurNOption ~= nil and self.recurNOption.setDisabled ~= nil then
        self.recurNOption:setDisabled(not needN)
    end
    if self.startPeriodOption ~= nil and self.startPeriodOption.setDisabled ~= nil then
        self.startPeriodOption:setDisabled(not needStart)
    end

    self:relayoutForm()
end

function EditTaskFrame:onOpen()
    EditTaskFrame:superClass().onOpen(self)
    local p = EditTaskFrame._params
    EditTaskFrame._params = nil
    if p == nil then
        self:close()
        return
    end
    self.groupId = p.groupId
    self.group = p.group
    self.task = p.task
    self.isEdit = p.isEdit
    self._reopenManageTasks = p.reopenManageTasks == true

    if self.isEdit then
        self.titleText:setText(g_i18n:getText("ui_edit_task"))
    else
        self.titleText:setText(g_i18n:getText("ui_add_task"))
    end

    self:withSuppressedOptionCallbacks(function()
        if self:shouldShowTaskType() then
            self:populateTaskTypeOption()
        else
            self.task.type = Task.TASK_TYPE.Standard
        end
        self:syncStandardWidgetsFromTask()
        self:populateLinkedForCurrentType()
    end)
    self:updateVisibility()
end

function EditTaskFrame:onClose()
    local reopenManage = self._reopenManageTasks == true
    self._reopenManageTasks = false
    EditTaskFrame:superClass().onClose(self)
    self.groupId = nil
    self.group = nil
    self.task = nil
    self._optionCallbackSuppressDepth = 0
    if reopenManage then
        g_gui:showDialog("manageTasksFrame")
    end
end

function EditTaskFrame:onTaskTypeChange(index)
    if self:_optionCallbacksSuppressed() then
        return
    end
    if self.task.type == Task.TASK_TYPE.Standard then
        self:readDetailFromUi()
    end
    self.task.type = self._taskTypeOrder[index] or Task.TASK_TYPE.Standard
    self:withSuppressedOptionCallbacks(function()
        self:populateLinkedForCurrentType()
    end)
    self:updateVisibility()
    if self.task.type == Task.TASK_TYPE.Standard then
        self:withSuppressedOptionCallbacks(function()
            self:syncStandardWidgetsFromTask()
        end)
        self:updateVisibility()
    end
end

function EditTaskFrame:onEffortChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onPriorityChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onShouldRecurChange(index)
    if self:_optionCallbacksSuppressed() then return end
    self:withSuppressedOptionCallbacks(function()
        self:populateRecurNOption()
    end)
    self:updateVisibility()
end
function EditTaskFrame:onRecurModeChange(index)
    if self:_optionCallbacksSuppressed() then return end
    self:withSuppressedOptionCallbacks(function()
        self:populateRecurNOption()
    end)
    self:updateVisibility()
end
function EditTaskFrame:onRecurNChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onStartPeriodChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onPeriodChange(index)
    if self:_optionCallbacksSuppressed() then return end
end

function EditTaskFrame:onHusbandryChange(index)
    if self:_optionCallbacksSuppressed() then return end
    local h = self._husbandryList[index]
    if h ~= nil then
        self.task.objectId = h.id
    end
    if self.task.type == Task.TASK_TYPE.HusbandryFood then
        self:withSuppressedOptionCallbacks(function()
            self:populateFoodOptions()
        end)
    elseif self.task.type == Task.TASK_TYPE.HusbandryConditions then
        self:withSuppressedOptionCallbacks(function()
            self:populateConditionOptions()
        end)
    end
end

function EditTaskFrame:onFoodTypeChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onFoodLevelChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onConditionTypeChange(index)
    if self:_optionCallbacksSuppressed() then return end
    local key = self._conditionKeys[index]
    if key ~= nil then
        self.task.husbandryCondition = key
    end
    self:withSuppressedOptionCallbacks(function()
        self:populateConditionOptions()
    end)
end
function EditTaskFrame:onConditionEvalChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onConditionLevelChange(index)
    if self:_optionCallbacksSuppressed() then return end
end

function EditTaskFrame:onProductionChange(index)
    if self:_optionCallbacksSuppressed() then return end
    local pr = self._productionList[index]
    if pr ~= nil then
        self.task.objectId = pr.id
    end
    self:withSuppressedOptionCallbacks(function()
        self:populateProductionFillAndLevel()
    end)
end

function EditTaskFrame:onProductionIoChange(index)
    if self:_optionCallbacksSuppressed() then return end
    self.task.productionType = index
    self:withSuppressedOptionCallbacks(function()
        self:populateProductionFillAndLevel()
    end)
end

function EditTaskFrame:onProductionFillChange(index)
    if self:_optionCallbacksSuppressed() then return end
    local key = self._fillKeys[index]
    if key ~= nil then
        self.task.productionFillType = key
    end
    self:withSuppressedOptionCallbacks(function()
        self:populateProductionFillAndLevel()
    end)
end

function EditTaskFrame:onProductionEvalChange(index)
    if self:_optionCallbacksSuppressed() then return end
end
function EditTaskFrame:onProductionLevelChange(index)
    if self:_optionCallbacksSuppressed() then return end
end

function EditTaskFrame:getTaskDetailInputText()
    if self.taskDetailInput == nil then
        return ""
    end
    if self.taskDetailInput.getText ~= nil then
        return self.taskDetailInput:getText() or ""
    end
    return self.taskDetailInput.text or ""
end

function EditTaskFrame:setTaskDetailInputText(text)
    if self.taskDetailInput ~= nil and self.taskDetailInput.setText ~= nil then
        self.taskDetailInput:setText(text or "")
    end
end

function EditTaskFrame:readDetailFromUi()
    self.task.detail = limitTaskDetailLength(self:getTaskDetailInputText(), Task.MAX_DETAIL_LENGTH)
end

function EditTaskFrame:readStandardFromUi()
    self:readDetailFromUi()
    self.task.effort = self.effortOption:getState()
    self.task.priority = self.priorityOption:getState()
    self.task.shouldRecur = self.shouldRecurOption:getState() == 1
    if self.task.shouldRecur then
        self.task.recurMode = self.recurModeOption:getState()
        if self.task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS or self.task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
            local nv = self._recurNValues[self.recurNOption:getState()]
            self.task.n = nv or 1
        else
            self.task.n = 0
        end
        if self.task.recurMode == Task.RECUR_MODE.EVERY_N_MONTHS then
            self.task.nextN = TaskListUtils.convertMonthNumberToPeriod(self.startPeriodOption:getState())
        elseif self.task.recurMode == Task.RECUR_MODE.EVERY_N_DAYS then
            self.task.nextN = g_currentMission.environment.currentDay
        else
            self.task.nextN = 0
        end
        if self.task.recurMode == Task.RECUR_MODE.MONTHLY then
            self.task.period = TaskListUtils.convertMonthNumberToPeriod(self.periodOption:getState())
        end
    else
        self.task.recurMode = Task.RECUR_MODE.NONE
        self.task.n = 0
        self.task.nextN = 0
        self.task.period = TaskListUtils.convertMonthNumberToPeriod(self.periodOption:getState())
    end
end

function EditTaskFrame:readLinkedFromUi()
    local t = self.task.type
    if t == Task.TASK_TYPE.HusbandryFood then
        local h = self._husbandryList[self.husbandryOption:getState()]
        if h ~= nil then
            self.task.objectId = h.id
        end
        if self._foodKeys ~= nil then
            local fk = self._foodKeys[self.foodTypeOption:getState()]
            if fk ~= nil then
                self.task.husbandryFood = fk
            end
        end
        local husbandry = g_currentMission.taskList:getHusbandries()[self.task:getObjectId()]
        if husbandry ~= nil then
            local idx = self.foodLevelOption:getState()
            self.task.husbandryLevel = self:applyLevelFromState(idx, husbandry.foodCapacity)
        end
    elseif t == Task.TASK_TYPE.HusbandryConditions then
        local h = self._husbandryList[self.husbandryOption:getState()]
        if h ~= nil then
            self.task.objectId = h.id
        end
        if self._conditionKeys ~= nil then
            local ck = self._conditionKeys[self.conditionTypeOption:getState()]
            if ck ~= nil then
                self.task.husbandryCondition = ck
            end
        end
        self.task.evaluator = self.conditionEvalOption:getState()
        local husbandry = g_currentMission.taskList:getHusbandries()[self.task:getObjectId()]
        if husbandry ~= nil then
            local ci = husbandry.conditionInfos[self.task.husbandryCondition]
            if ci ~= nil then
                self.task.husbandryLevel = self:applyLevelFromState(self.conditionLevelOption:getState(), ci.capacity)
            end
        end
    elseif t == Task.TASK_TYPE.Production then
        local pr = self._productionList[self.productionOption:getState()]
        if pr ~= nil then
            self.task.objectId = pr.id
        end
        self.task.productionType = self.productionIoOption:getState()
        if self._fillKeys ~= nil then
            local fk = self._fillKeys[self.productionFillOption:getState()]
            if fk ~= nil then
                self.task.productionFillType = fk
            end
        end
        self.task.evaluator = self.productionEvalOption:getState()
        local production = g_currentMission.taskList:getProductions()[self.task:getObjectId()]
        if production ~= nil then
            local fillInfo = nil
            if self.task.productionType == Task.PRODUCTION_TYPE.INPUT then
                fillInfo = production.inputs[self.task.productionFillType]
            else
                fillInfo = production.outputs[self.task.productionFillType]
            end
            if fillInfo ~= nil then
                self.task.productionLevel = self:applyLevelFromState(self.productionLevelOption:getState(), fillInfo.capacity)
            end
        end
    end
end

function EditTaskFrame:onClickSave()
    if self:shouldShowTaskType() then
        self.task.type = self._taskTypeOrder[self.taskTypeOption:getState()] or Task.TASK_TYPE.Standard
    else
        self.task.type = Task.TASK_TYPE.Standard
    end

    if self.task.type == Task.TASK_TYPE.Standard then
        self:readStandardFromUi()
        if self.task.detail == "" then
            InfoDialog.show(g_i18n:getText("ui_no_detail_specified_error"))
            return
        end
    else
        self:readLinkedFromUi()
        if not self.task:isValid() then
            InfoDialog.show(g_i18n:getText("ui_task_form_incomplete"))
            return
        end
    end

    g_currentMission.taskList:addTask(self.groupId, self.task, self.isEdit)
    self:close()
end

function EditTaskFrame:onClickCancel()
    self:close()
end
