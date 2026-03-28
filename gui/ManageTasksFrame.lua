ManageTasksFrame = {}
ManageTasksFrame.availableGroups = {}
local ManageTasksFrame_mt = Class(ManageTasksFrame, MessageDialog)
ManageTasksFrame.groupSortingFunction = function(k1, k2) return k1.name < k2.name end

function ManageTasksFrame.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or ManageTasksFrame_mt)
    self.i18n = g_i18n
    self.selectedTaskIndex = -1
    self.currentGroupId = -1
    return self
end

function ManageTasksFrame:onCreate()
    ManageTasksFrame:superClass().onCreate(self)
end

function ManageTasksFrame:onGuiSetupFinished()
    ManageTasksFrame:superClass().onGuiSetupFinished(self)
    self.tasksTable:setDataSource(self)
    self.tasksTable:setDelegate(self)
end

function ManageTasksFrame:onOpen()
    ManageTasksFrame:superClass().onOpen(self)
    self.currentGroupId = -1
    self.selectedTaskIndex = -1

    g_messageCenter:subscribe(MessageType.TASK_GROUPS_UPDATED, function(menu)
        self:updateContent()
    end, self)
    self:updateContent()
    FocusManager:setFocus(self.groupSelector)
end

function ManageTasksFrame:onClose()
    ManageTasksFrame:superClass().onClose(self)
    g_messageCenter:unsubscribeAll(self)
end

function ManageTasksFrame:updateContent()
    local farmGroups = g_currentMission.taskList:getGroupListForCurrentFarm()
    -- Limit shown groups to templates or standard groups
    self.availableGroups = {}
    for _, group in pairs(farmGroups) do
        if group.type ~= TaskGroup.GROUP_TYPE.TemplateInstance then
            table.insert(self.availableGroups, group)
        end
    end

    table.sort(self.availableGroups, ManageTasksFrame.groupSortingFunction)

    local texts = {}
    for _, group in pairs(self.availableGroups) do
        table.insert(texts, group.name)
    end
    self.groupSelector:setTexts(texts)

    -- Check there are any groups
    if next(self.availableGroups) == nil then
        self.tasksContainer:setVisible(false)
        self.noTasksContainer:setVisible(false)
        self.noGroupsContainer:setVisible(true)
        return
    end

    self.noGroupsContainer:setVisible(false)

    -- If there are groups but the currentGroupId is not there, find one to show
    self.currentGroup = g_currentMission.taskList:getGroupById(self.currentGroupId, false)
    if self.currentGroup == nil then
        for i, group in pairs(self.availableGroups) do
            self.currentGroup = g_currentMission.taskList:getGroupById(group.id, false)
            self.currentGroupId = group.id
            self.groupSelector:setState(i, false)
            break
        end
    end

    -- Check if any tasks on the current Group. If not hide the table and return
    if next(self.currentGroup.tasks) == nil then
        self.tasksContainer:setVisible(false)
        self.noTasksContainer:setVisible(true)
        return
    end
    table.sort(self.currentGroup.tasks, TaskListUtils.taskSortingFunction)

    self.tasksContainer:setVisible(true)
    self.noTasksContainer:setVisible(false)

    self.tasksTable:reloadData()
end

function ManageTasksFrame:getNumberOfSections()
    return 1
end

function ManageTasksFrame:getNumberOfItemsInSection(list, section)
    local count = 0
    for _ in pairs(self.currentGroup.tasks) do count = count + 1 end
    return count
end

function ManageTasksFrame:getTitleForSectionHeader(list, section)
    return ""
end

function ManageTasksFrame:populateCellForItemInSection(list, section, index, cell)
    local task = self.currentGroup.tasks[index]

    cell:getAttribute("detail"):setText(task:getTaskDescription())
    cell:getAttribute("effort"):setText(task:getEffortDescription(self.currentGroup.effortMultiplier))
    cell:getAttribute("priority"):setText(task.priority)
    cell:getAttribute("due"):setText(task:getDueDescription())
end

function ManageTasksFrame:onListSelectionChanged(list, section, index)
    self.selectedTaskIndex = index
end

function ManageTasksFrame:onClickBack(sender)
    self:close()
end

function ManageTasksFrame:onClickAdd(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end

    EditTaskFrame.open(self.currentGroupId, self.currentGroup, Task.new(), false)
end

function ManageTasksFrame:onClickEdit(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end

    local task = self.currentGroup.tasks[self.selectedTaskIndex]
    if task == nil then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    EditTaskFrame.open(self.currentGroupId, self.currentGroup, task, true)
end

function ManageTasksFrame:onClickDelete(sender)
    if self.currentGroupId == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_group_selected"))
        return
    end
    if self.selectedTaskIndex == -1 then
        InfoDialog.show(g_i18n:getText("ui_no_task_selected"))
        return
    end
    YesNoDialog.show(
        ManageTasksFrame.onRespondToDeletePrompt, self,
        g_i18n:getText("ui_confirm_deletion"))
end

function ManageTasksFrame:onRespondToDeletePrompt(clickOk)
    if clickOk then
        g_currentMission.taskList:deleteTask(self.currentGroup.id, self.currentGroup.tasks[self.selectedTaskIndex].id)
    end
end

function ManageTasksFrame:OnGroupSelectChange(index)
    self.currentGroupId = self.availableGroups[index].id
    self:updateContent()
end
