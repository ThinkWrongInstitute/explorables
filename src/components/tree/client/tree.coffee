#########
# GRAPH #
#########
#
#

Template.body.events
	"click .save-draft": (event) ->
		if(Meteor.user())
			allTuts = Tutorials.find({}).fetch()
			_.each allTuts, (t) ->
				Meteor.call("saveTutorialLocation", t, "save")
			$("body").removeClass "draft-mode"
			$(".node").removeClass "draft-node"
			Session.set "draft-mode", "False"

	"click .discard-draft": ->
		if(Meteor.user())
			allTuts = Tutorials.find({}).fetch()
			_.each allTuts, (t) ->
				Meteor.call("saveTutorialLocation", t, "discard")
			$("body").removeClass "draft-mode"
			$(".node").removeClass "draft-node"
			Session.set "draft-mode", "False"
			jsPlumb.repaintEverything()

	"submit .new-tutorial": (event) ->
		event.preventDefault()

		console.log('adding new tutorial')

		Meteor.call "addTutorial"
		# Clear form
		event.target.title.value = ""
		nodes_dep.changed

SkillTreeBezier = ->
	_super =  jsPlumb.Connectors.AbstractConnector.apply(this, arguments);

	this.type = "SkillTreeBezier"
	this._compute = (paintInfo) ->

		x1 = paintInfo.sx
		y1 = paintInfo.sy + 40
		x2 = paintInfo.tx
		y2 = paintInfo.ty + 40

		#segment to end point
		_super.addSegment this, "Bezier",
			x1:x1
			y1:y1
			x2:x2
			y2:y2
			cp1x: ((x2 + x1) / 2 - (Math.sqrt(y1 + y2) / 2))
			cp1y: y1,
			cp2x: ((x2 + x1) / 2 + (Math.sqrt(y1 + y2) / 2))
			cp2y: y2

jsPlumbUtil.extend(SkillTreeBezier, jsPlumb.Connectors.AbstractConnector);
jsPlumb.registerConnectorType(SkillTreeBezier, "SkillTreeBezier");

jsPlumb.importDefaults
	Connector : [ "SkillTreeBezier", { curviness: 35, cornerRadius: 30 } ]
	PaintStyle :
		strokeStyle: "gray", 
		lineWidth: 1.5, 
		dashstyle: '3 2' 
	Anchor : [ "Left", "Right" ]
	EndpointStyle : { radius: 0 }
#	DragOptions : { cursor: "crosshair" }
#	Endpoint : [ "Dot", { radius:7 } ] 
#	EndpointStyle : {fillStyle:'pink'}
#	Overlays: [[ "Arrow", { width:5, length:5, location:0, direction: -1, id:"arrow" } ]]
#	EndpointHoverStyle: { fillStyle: "orange" }
#	HoverPaintStyle: { strokeStyle: "orange" }
#	ConnectionsDetachable:true
#	ReattachConnections:true
#	DropOptions:
#		tolerance: "touch"
#		hoverClass: "dropHover"
#		activeClass: "dragActive"

sourceEndpoint = {
	isSource: true
	maxConnections: -1
}
targetEndpoint = {
	isTarget: true
	maxConnections: -1
}


Session.set "dep-mode", "False"
Session.set "nodes-rendered", 0
nodes_dep = new Deps.Dependency()

endDepMode = (end_id) ->
	$("body").removeClass "dep-mode"
	$("#column-navtree").unbind "mousemove"
	$("#depline").remove()
	Session.set "dep-mode", "False"
	tut1_id = [ end_id, Session.get("dep-from") ].sort()[0]
	tut2_id = [ end_id, Session.get("dep-from") ].sort()[1]
	Session.set "dep-from", ""
	Meteor.subscribe("links")
	existingLinks = Links.find(
		tutorial1: tut1_id
		tutorial2: tut2_id
	).fetch()

	if existingLinks.length > 0
		console.log "removing dep"
		conns = jsPlumb.getConnections
			source: $("#node-" + tut1_id + ' .icon')
			target: $("#node-" + tut2_id + ' .icon')
		_.each conns, (c) ->
			jsPlumb.detach c
		_.each existingLinks, (d) ->
			Links.remove d._id
	else if tut1_id != tut2_id
		console.log "adding dep " + tut1_id + "-->" + tut2_id
		Links.insert
			tutorial1: tut1_id
			tutorial2: tut2_id
			createdAt: new Date() # current time
		nodes_dep.changed
	drawLinks(tut1_id)

# this gets updated and passed into the minimap
containerWidth = 0
containerHeight = 0

Template.node.helpers
	xpos: ->
		if this.x * GRID_MULTIPLIER_X > containerWidth + 80
			containerWidth = this.x * GRID_MULTIPLIER_X + 80
			Session.set('containerWidth', containerWidth)
		if(Meteor.user())
			this.draft_x * GRID_MULTIPLIER_X
		else
			this.x * GRID_MULTIPLIER_X
	ypos: ->
		if this.y * GRID_MULTIPLIER_Y > containerHeight + 80
			containerHeight = this.y * GRID_MULTIPLIER_Y + 80
			Session.set('containerHeight', containerHeight + 80)
		if(Meteor.user())
			this.draft_y * GRID_MULTIPLIER_Y
		else
			this.y * GRID_MULTIPLIER_Y
	draftMode: ->
		nodes_dep.depend()
		that = this
		if this.draft_y != this.y or this.draft_x != this.x
			$("body").addClass "draft-mode"
			return "draft-node"
	nodeIcon: ->
		icon_id = this.icon_id
		icon = s3Icons.findOne({ _id: icon_id })

		s3url = (id, name) ->
			return (BUCKET_URL + 'icons/images/' + id + '-' + name)

		if (icon)
			return s3url(icon._id, icon.original.name)
		return DEFAULT_ICON
	nodeUrl: ->
		if this.slug
			return "/tutorial/" + this.slug
		else 
			return "/tutorial/" + this._id 


Template.node.events 

	"click": (event) ->
		$('body').addClass('viewing-node')

		tutid = this._id
		node = $("#node-" + tutid)
		tutorial = $(".tutorial")

		$('.node').not(node).removeClass "courseSelect courseHover"

		if Session.get("dep-mode") is "True"
			endDepMode(this._id)
		else
			# not in week mode
			unless Session.get("week-mode") is "True"
				if !node.hasClass "courseSelect"

					tutorial.fadeOut(100, () ->
						tutorial.fadeIn(100);
					);

					$('body').removeClass('node-content-hidden')

					if node.offset().left > 0.5 * $(window).width()
						$('#column-navtree').animate({
							scrollLeft: node.offset().left - 0.25 * $(window).width()
						})
				else
					$('body').removeClass('viewing-node')

				node.toggleClass "courseSelect"
				
			# viewing a week, only show nodes in that week
			else
				weekfrom = Session.get("week-mode-from")
				weeksnodes = Weeks.findOne(_id: weekfrom).nodes

				if node.hasClass 'weekmodeHighlight'
					tutorial.fadeOut(100, () ->
						tutorial.fadeIn(100);
					);

					if node.offset().left > 0.5 * $(window).width()
						$('#column-navtree').animate({
							scrollLeft: node.offset().left - 0.25 * $(window).width()
						})
				else
					$('body').removeClass('viewing-node')

	"click .change-dep": (e) ->
		if (Meteor.user())

			if Session.get("dep-mode") != "True"
				console.log('starting dep mode')
				$("body").addClass "dep-mode"
				Session.set "dep-mode", "True"
				Session.set "dep-from", this._id

				# draw line from right side of node
				mouseX = (this.draft_x + 2) * GRID_MULTIPLIER_X
				mouseY = this.draft_y * GRID_MULTIPLIER_Y + 45
				
				$("body").on "mousemove", (e) ->
					$("#column-navtree").line(mouseX, mouseY, e.offsetX, e.offsetY, {id: 'depline'})
			else
				console.log('ending dep mode')
				endDepMode(this._id)



Template.node.rendered = ->

	Session.set("nodes-rendered", Session.get("nodes-rendered") + 1)

	Meteor.subscribe "tutorials"
	Meteor.subscribe "links"

	tuts = Tutorials.find {},
		sort:
			createdAt: -1
	tutcount = tuts.count()
	if (Session.get("nodes-rendered") == tutcount)
		_.each tuts.fetch(), (t) ->
			drawLinks t._id


	if(Meteor.user())
		thisIcon = $(".node#node-" + this.data._id + " .icon")
#		jsPlumb.addEndpoint(thisIcon, sourceEndpoint, {anchor: [[1, 0.5, 1, 0]]})
#		jsPlumb.addEndpoint(thisIcon, targetEndpoint, {anchor: [[0, 0.5, -1, 0]]})

		jsPlumb.draggable $(".node#node-" + this.data._id),
			grid: [ GRID_MULTIPLIER_X, GRID_MULTIPLIER_Y ]
			drag: (event) -> 
				console.log(event.pos[0] + "/" + event.pos[1])
			stop: (event) -> # fired when an item is dropped
				$("body").addClass "draft-mode"
				Session.set "draft-mode", "True"
				console.log $(event.el)
				tut = Blaze.getData(event.el)
				$(".node#node-" + tut._id).addClass("draft-node")

				console.log(event.pos[0] + "/" + event.pos[1])
				Meteor.call("moveTutorial", tut, event.pos[0] / GRID_MULTIPLIER_X, event.pos[1] / GRID_MULTIPLIER_Y)

				jsPlumb.repaintEverything()


drawLinks = (from_id) ->
	"""
	console.log("drawLinks")
	Meteor.subscribe "links"
	Meteor.subscribe "tutorials"

	_.each Links.find({tutorial1: from_id}).fetch(), (d) ->
		jsPlumb.setContainer("tree-links")
		jsPlumb.connect
			source: $('#node-' + d.tutorial1 + ' .icon')
			target: $('#node-' + d.tutorial2 + ' .icon')
			deleteEndpointsOnDetach:false
			newConnection:true 
	"""

drawAllLinks = () ->
	console.log("drawLinks")
	Meteor.subscribe "links"
	Meteor.subscribe "tutorials"


	_.each Links.find({}).fetch(), (d) ->
		jsPlumb.setContainer("tree-links")
		jsPlumb.connect
			source: $('#node-' + d.tutorial1 + ' .icon')
			target: $('#node-' + d.tutorial2 + ' .icon')
			reattach:true
			detachable: true
			newConnection: false
			deleteEndpointsOnDetach:false 
			



Template.tree.helpers nodes: ->
	Meteor.subscribe("tutorials")
	return Tutorials.find {},
		sort:
			createdAt: -1

Template.tree.rendered = ->

	drawAllLinks()

	$('#column-navtree').dragScroll({
		exclude: '.node, #minimap'
	});

