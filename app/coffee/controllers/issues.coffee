# Copyright 2013 Andrey Antukh <niwi@niwi.be>
#
# Licensed under the Apache License, Version 2.0 (the "License")
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

IssuesController = ($scope, $rootScope, $routeParams, $filter, $q, rs) ->
    # Global Scope Variables
    $rootScope.pageSection = 'issues'
    $rootScope.projectId = parseInt($routeParams.pid, 10)

    projectId = $rootScope.projectId

    $scope.filtersOpened = false
    $scope.issueFormOpened = false

    # Pagination variables
    $scope.filteredItems = []
    $scope.groupedItems = []
    $scope.itemsPerPage = 15
    $scope.pagedItems = []
    $scope.currentPage = 0

    $scope.sortingOrder = 'severity'
    $scope.reverse = false

    # Load initial data
    rs.getProject($rootScope.projectId).then (project) ->
        $rootScope.project = project
        $rootScope.pageBreadcrumb = [project.name, "Issues"]
        $rootScope.$broadcast("project:loaded", project)

    generateTagList = ->
        tagsDict = {}
        tags = []

        _.each $scope.issues, (iss) ->
            _.each iss.tags, (tag) ->
                if tagsDict[tag] is undefined
                    tagsDict[tag] = 1
                else
                    tagsDict[tag] += 1

        _.each tagsDict, (val, key) ->
            tags.push({name:key, count:val})

        $scope.tags = tags

    generateAssignedToTags = ->
        users = $rootScope.constants.usersList

        $scope.assignedToTags = _.map users, (user) ->
            issues = _.filter($scope.issues, {"assigned_to": user.id})
            return {"id": user.id, "name": user.username, "count": issues.length}

    generateStatusTags = ->
        statuses = $rootScope.constants.statusList

        $scope.statusTags = _.map statuses, (status) ->
            issues = _.filter($scope.issues, {"status": status.id})
            return {"id": status.id, "name": status.name, "count": issues.length}

    regenerateTags = ->
        generateTagList()
        generateAssignedToTags()
        generateStatusTags()

    filterIssues = ->
        for issue in $scope.issues
            issue.__hidden = false

        # Filter by generic tags
        selectedTags = _.filter($scope.tags, "selected")
        selectedTagsIds = _.map(selectedTags, "name")

        if selectedTagsIds.length > 0
            for item in $scope.issues
                interSection = _.intersection(selectedTagsIds, item.tags)

                if interSection.length == 0
                    item.__hidden = true
                else
                    item.__hidden = false

        # Filter by assigned to tags
        selectedUsers = _.filter($scope.assignedToTags, "selected")

        if not _.isEmpty(selectedUsers)
            for item in $scope.issues
                continue if item.__hidden

                result = _.some(selectedUsers, {"id": item.assigned_to})
                item.__hidden = true if not result

        # Filter by status tags
        selectedStatuses = _.filter($scope.statusTags, "selected")
        if not _.isEmpty(selectedStatuses)
            for item in $scope.issues
                continue if item.__hidden

                result = _.some(selectedStatuses, {"id": item.status})
                item.__hidden = true if not result

        groupToPages()

    groupToPages = ->
        $scope.pagedItems = []

        issues = _.reject($scope.issues, "__hidden")
        issues = $filter("orderBy")(issues, $scope.sortingOrder, $scope.reverse)

        for issue, i in issues
            if i % $scope.itemsPerPage == 0
                $scope.pagedItems[Math.floor(i / $scope.itemsPerPage)] = [issue]
            else
                $scope.pagedItems[Math.floor(i / $scope.itemsPerPage)].push(issue)

    $scope.prevPage = ->
        if $scope.currentPage > 0
            $scope.currentPage--

    $scope.nextPage = ->
        if $scope.currentPage < ($scope.pagedItems.length - 1)
            $scope.currentPage++

    $scope.setPage = ->
        $scope.currentPage = this.n

    $scope.range = (start, end) ->
        ret = []
        if not end?
            end = start
            start = 0

        ret.push(i) for i in [start..end-1]
        return ret

    $scope.selectTag = (tag) ->
        tag.selected = if tag.selected then false else true

        $scope.currentPage = 0
        filterIssues()

    $scope.$watch("sortingOrder", groupToPages)
    $scope.$watch("reverse", groupToPages)

    promise = $q.all([
        rs.getIssueTypes(projectId),
        rs.getIssueStatuses(projectId),
        rs.getSeverities(projectId),
        rs.getPriorities(projectId),
        rs.getUsers(projectId),
        rs.getIssues(projectId)
        rs.getRoles(),
    ])

    promise = promise.then (results) ->
        issueTypes = results[0]
        issueStatuses = results[1]
        severities = results[2]
        priorities = results[3]
        users = results[4]
        issues = results[5]

        _.each(users, (item) -> $rootScope.constants.users[item.id] = item)
        _.each(issueTypes, (item) -> $rootScope.constants.type[item.id] = item)
        _.each(issueStatuses, (item) -> $rootScope.constants.status[item.id] = item)
        _.each(severities, (item) -> $rootScope.constants.severity[item.id] = item)
        _.each(priorities, (item) -> $rootScope.constants.priority[item.id] = item)


        $rootScope.constants.typeList = _.sortBy(issueTypes, "order")
        $rootScope.constants.statusList = _.sortBy(issueStatuses, "order")
        $rootScope.constants.severityList = _.sortBy(severities, "order")
        $rootScope.constants.priorityList = _.sortBy(priorities, "order")
        $rootScope.constants.usersList = _.sortBy(users, "id")

        $scope.issues = issues
        regenerateTags()
        filterIssues()

    $scope.updateIssueAssignation = (issue, id) ->
        issue.assigned_to = id || null
        issue.save()
        regenerateTags()

    $scope.updateIssueStatus = (issue, id) ->
        issue.status = id
        issue.save()
        regenerateTags()

    $scope.updateIssueSeverity = (issue, id) ->
        issue.severity = id
        issue.save()
        regenerateTags()

    $scope.updateIssuePriority = (issue, id) ->
        issue.priority = id
        issue.save()
        regenerateTags()

    $scope.submit = ->
        rs.createIssue($scope.projectId, $scope.form).then (issue) ->
            $scope.form = {}
            $scope.issues.push(us)

            regenerateTags()
            filterIssues()

    $scope.removeIssue = (issue) ->
        issue.remove().then ->
            index = $scope.issues.indexOf(issue)
            $scope.issues.splice(index, 1)

            regenerateTags()
            filterIssues()



IssuesViewController = ($scope, $location, $rootScope, $routeParams, $q, rs) ->
    $rootScope.pageSection = 'issues'
    $rootScope.projectId = parseInt($routeParams.pid, 10)
    $rootScope.pageBreadcrumb = ["", "Issues", ""]

    projectId = $rootScope.projectId
    issueId = $routeParams.issueid

    $scope.issue = {}
    $scope.form = {}
    $scope.updateFormOpened = false

    # Load initial data
    rs.getProject($rootScope.projectId).then (project) ->
        $rootScope.project = project
        $rootScope.$broadcast("project:loaded", project)

        breadcrumb = _.clone($rootScope.pageBreadcrumb)
        breadcrumb[0] = project.name

        $rootScope.pageBreadcrumb = breadcrumb

    loadIssue = ->
        rs.getIssue(projectId, issueId).then (issue) ->
            $scope.issue = issue
            $scope.form = _.extend({}, $scope.issue._attrs)

            breadcrumb = _.clone($rootScope.pageBreadcrumb)
            breadcrumb[2] = "##{issue.ref}"

            $rootScope.pageBreadcrumb = breadcrumb

    loadAttachments = ->
        rs.getIssueAttachments(projectId, issueId).then (attachments) ->
            $scope.attachments = attachments

    # Load initial data
    loadAttachments()

    promise = $q.all [
        rs.getIssueTypes(projectId),
        rs.getIssueStatuses(projectId),
        rs.getSeverities(projectId),
        rs.getPriorities(projectId),
        rs.getUsers(projectId),
        rs.getIssueAttachments(projectId, issueId),
    ]

    promise.then (results) ->
        issueTypes = results[0]
        issueStatuses = results[1]
        severities = results[2]
        priorities = results[3]
        users = results[4]

        _.each(users, (item) -> $rootScope.constants.users[item.id] = item)
        _.each(issueTypes, (item) -> $rootScope.constants.type[item.id] = item)
        _.each(issueStatuses, (item) -> $rootScope.constants.status[item.id] = item)
        _.each(severities, (item) -> $rootScope.constants.severity[item.id] = item)
        _.each(priorities, (item) -> $rootScope.constants.priority[item.id] = item)

        $rootScope.constants.typeList = _.sortBy(issueTypes, "order")
        $rootScope.constants.statusList = _.sortBy(issueStatuses, "order")
        $rootScope.constants.severityList = _.sortBy(severities, "order")
        $rootScope.constants.priorityList = _.sortBy(priorities, "order")
        $rootScope.constants.usersList = _.sortBy(users, "id")

        loadIssue()

    $scope.isSameAs = (property, id) ->
        return ($scope.issue[property] == parseInt(id, 10))

    $scope.submit = ->
        $rootScope.$broadcast("flash:new", true, "La issue se ha guardado!")
        rs.uploadIssueAttachment(projectId, issueId, $scope.attachment)

        for key, value of $scope.form
            $scope.issue[key] = value

        $scope.issue.save().then (issue) ->
            loadIssue()
            loadAttachments()

    $scope.removeAttachment = (attachment) ->
        $scope.attachments = _.reject($scope.attachments, {"id": attachment.id})
        attachment.remove()

    $scope.removeIssue = (issue) ->
        issue.remove().then ->
            $location.url("/project/#{projectId}/issues/")


module = angular.module("greenmine.controllers.issues", [])
module.controller("IssuesViewController", ['$scope', '$location', '$rootScope', '$routeParams', '$q', 'resource', IssuesViewController])
module.controller("IssuesController", ['$scope', '$rootScope', '$routeParams', '$filter', '$q', 'resource', IssuesController])
