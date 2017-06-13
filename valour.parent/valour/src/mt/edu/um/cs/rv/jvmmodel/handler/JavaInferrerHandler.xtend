package mt.edu.um.cs.rv.jvmmodel.handler;

import com.google.common.collect.ArrayListMultimap
import com.google.common.collect.Multimap
import java.util.ArrayList
import java.util.HashSet
import java.util.List
import java.util.Map
import java.util.Set
import java.util.Stack
import javax.inject.Inject
import mt.edu.um.cs.rv.compilation.ValourAnnotationDecorator
import mt.edu.um.cs.rv.utils.ValourScriptTraverser
import mt.edu.um.cs.rv.valour.Action
import mt.edu.um.cs.rv.valour.BasicRule
import mt.edu.um.cs.rv.valour.CategorisationClause
import mt.edu.um.cs.rv.valour.Category
import mt.edu.um.cs.rv.valour.Condition
import mt.edu.um.cs.rv.valour.ControlFlowTrigger
import mt.edu.um.cs.rv.valour.Event
import mt.edu.um.cs.rv.valour.EventTrigger
import mt.edu.um.cs.rv.valour.ForEach
import mt.edu.um.cs.rv.valour.Model
import mt.edu.um.cs.rv.valour.MonitorTrigger
import mt.edu.um.cs.rv.valour.ParForEach
import mt.edu.um.cs.rv.valour.Rule
import mt.edu.um.cs.rv.valour.StateBlock
import mt.edu.um.cs.rv.valour.StateDeclaration
import mt.edu.um.cs.rv.valour.ValourBody
import mt.edu.um.cs.rv.valour.WhenClause
import mt.edu.um.cs.rv.valour.WhereClause
import mt.edu.um.cs.rv.valour.WhereClauses
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.xbase.compiler.output.ITreeAppendable
import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.xbase.jvmmodel.JvmAnnotationReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmTypeReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1
import org.eclipse.xtext.xtype.XImportSection
import java.util.stream.Collectors
import mt.edu.um.cs.rv.valour.ExternalTrigger
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.JvmFormalParameter
import org.eclipse.xtext.common.types.JvmField

public class JavaInferrerHandler extends InferrerHandler {

	/**
	 * convenience API to build and initialize JVM types and their members.
	 */
	@Inject extension JvmTypesBuilder

	@Inject extension IJvmModelAssociations
	@Inject extension IQualifiedNameProvider

	@Inject extension ValourScriptTraverser

	@Inject extension ValourAnnotationDecorator

	var Model model
	var IJvmDeclaredTypeAcceptor acceptor

	var monitorCounter = 1;
	var eventCounter = 1;
	var actionCounter = 1;
	var conditionCounter = 1;
	var stateCounter = 1;
	var monitorTriggers = 1;

	@Extension JvmAnnotationReferenceBuilder _annotationTypesBuilder;
	@Extension JvmTypeReferenceBuilder _typeReferenceBuilder;

	Stack<Set<String>> requiredEventsStack = new Stack()
	Stack<Multimap<String, String>> eventMonitorsStack = new Stack()
	
	List<EObject> topLevelRules = new ArrayList()

	override void setup(JvmAnnotationReferenceBuilder _annotationTypesBuilder,
		JvmTypeReferenceBuilder _typeReferenceBuilder) {
		this._annotationTypesBuilder = _annotationTypesBuilder
		this._typeReferenceBuilder = _typeReferenceBuilder
	}

	override initialise(Model model, IJvmDeclaredTypeAcceptor acceptor) {

		this.model = model
		this.acceptor = acceptor

		// TODO the package to which to generate the classes should be defined in the language ???
		val packageName = packageNameToUse(model)

		val String monitoringSystemClassName = packageName + ".MonitoringSystem"
		var JvmGenericType monitoringSystemClass = model.toClass(
			monitoringSystemClassName,
			[
				annotations += annotationRef("org.springframework.boot.autoconfigure.SpringBootApplication")
				annotations += model.toAnnotationRef(
					"org.springframework.context.annotation.Import",
					Pair.of("value", typeRef("mt.edu.um.cs.rv.eventmanager.engine.config.EventManagerConfigration"))
				)
				members += model.toMethod(
					"main",
					typeRef(void),
					[
						static = true
						visibility = JvmVisibility.PUBLIC
						parameters += model.toParameter("args", typeRef(String).addArrayTypeDimension)
						body = '''
							org.springframework.boot.SpringApplication.run(«monitoringSystemClassName».class, args);
						'''
					]
				)

			]
		)

		acceptor.accept(
			monitoringSystemClass
		)
	}

// TODO the package to which to generate the classes should be defined in the language ???
	def String packageNameToUse(EObject eObject) {
		val inputFileName = eObject.eResource.URI.lastSegment
		val lastIndex = inputFileName.lastIndexOf('.valour')
		if (lastIndex > 0) {
			return "valour." + inputFileName.substring(0, lastIndex)
		} else {
			return "valour." + inputFileName.toLowerCase
		}

	}

	override handleImports(XImportSection imports) {
		// nothing to do here, this will be implemented automatically by Xtext
	}

	override handleDeclarationsBlockStart() {
		// nothing to do here
	}

	override handleDeclarationsBlockEnd() {
		// nothing to do here
	}

	override handleCategoryDeclaration(Category category) {
		// TODO if required
	}

	override handleEventDeclarationBegin(Event event) {
		val packageName = packageNameToUse(event) + ".events"
		val String className = packageName + ".Event" + (eventCounter++)

		val eventDecName = event.name + ' (' + formalParametersAsString(event.eventFormalParameters) + ')'

		val JvmGenericType eventClass = event.toClass(className, [
			static = false
			superTypes += typeRef("mt.edu.um.cs.rv.events.Event")
		])
		
		//create builder class (to be created in parallel with the event class)
		val JvmGenericType eventBuilderClass = event.toClass(className + "Builder", [
			static = false
		])
		

		if (event.eventFormalParameters != null && !event.eventFormalParameters.parameters.isNullOrEmpty) {

			// generate a private field for each event parameter
			event.eventFormalParameters.parameters.forEach [ param |
				eventClass.members += event.toField(
					param.name,
					param.parameterType
				)
				
				eventBuilderClass.members += event.toField(
					param.name,
					param.parameterType
				) 
			]

			// add constructor with all properties for event
			val constuctor = event.toConstructor [
				body = '''
					«FOR param : event.eventFormalParameters.parameters»
						this.«param.name» = «param.name»;
						«ENDFOR» 
				'''
			]
			eventClass.members += constuctor

			event.eventFormalParameters.parameters.forEach [ param |
				constuctor.parameters += param.toParameter(param.name, param.parameterType)
			]

			// for each event parameter
			event.eventFormalParameters.parameters.forEach [ param |
				//generate a getter method in the event class
				eventClass.members += event.toGetter(
					param.name,
					param.parameterType
				)
				
				//generate a setter method in the event builder class
				eventBuilderClass.members += event.toSetter(
					param.name,
					param.parameterType
				)
			]
		}
		
		//add build method to eventClassBuilder
		eventBuilderClass.members += event.toMethod("build", 
			typeRef(eventClass),
			[
				body = '''
				«eventClass.qualifiedName» event = new «eventClass.qualifiedName»(
					«IF (!event.eventFormalParameters.parameters.isNullOrEmpty)»
						«event.eventFormalParameters.parameters.stream.map[p | "this."+p.name].collect(Collectors.joining(", "))» 
					«ENDIF»
				);
				return event;
				'''
			]
		)
		
		eventBuilderClass.members += event.toMethod("build",
			typeRef(eventClass),
			[
				parameters += event.toParameter("synchronous", typeRef(boolean))
				body = '''
				«eventClass.qualifiedName» event = this.build();
				event.setSynchronous(synchronous);
				return event;
				'''
			]
		)
		
		
		eventClass.members += event.toField("synchronous", typeRef(Boolean), [
			static = false
			visibility = JvmVisibility.PRIVATE
			val Procedure1<ITreeAppendable> init = [
					append('''Boolean.TRUE''')
				]
			initializer = init 
		])

		eventClass.members += event.toMethod(
			"isSynchronous",
			typeRef(Boolean.TYPE),
			[
				static = false
				visibility = JvmVisibility.PUBLIC
				annotations += annotationRef(Override)
				body = '''return synchronous;'''
			]
		)
		
		eventClass.members += event.toSetter("synchronous", typeRef(Boolean))

		eventClass.members += event.toMethod(
			"toString",
			typeRef(String),
			[
				static = false
				visibility = JvmVisibility.PUBLIC
				annotations += annotationRef(Override)
				body = '''return "«eventDecName»";'''
			]
		)

		if (event.eventBody.categorisation != null) {

			val keyType = event.eventBody.categorisation.category.category.keyType
			eventClass.superTypes += typeRef("mt.edu.um.cs.rv.events.CategorisedEvent", keyType)

			eventClass.members += event.toMethod(
				"categoriseEvent",
				keyType,
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)

//					event.eventFormalParameters.parameters.forEach [ param |
//						parameters += param.toParameter(param.name, param.parameterType)
//					]
					if (event.eventBody.categorisation.categoryExpression.simple != null) {
						body = event.eventBody.categorisation.categoryExpression.simple
					} else {
						body = event.eventBody.categorisation.categoryExpression.complex
					}

				]
			)
		}

		acceptor.accept(
			eventClass
		)
		
		acceptor.accept(
			eventBuilderClass
		)
	}

	override handleEventDeclarationEnd(Event event) {
		// nothing to do here
	}

	override handleControlFlowTrigger(ControlFlowTrigger controlFlowTrigger, Boolean additionalTrigger) {
	}

	override handleEventTrigger(EventTrigger eventTrigger, Boolean additionalTrigger) {
	}

	override handleMonitorTrigger(MonitorTrigger monitorTrigger, Boolean additionalTrigger) {
		val packageName = packageNameToUse(monitorTrigger) + ".monitor_triggers"
		val monitorTriggerId = monitorTriggers++
		val String className = packageName + ".MonitorTrigger" + (monitorTriggerId)
		val String functionalInterfaceName = packageName + ".IMonitorTrigger" + (monitorTriggerId)

		val consumableFunctionalInterface = monitorTrigger.toClass(
			functionalInterfaceName,
			[
				annotations += annotationRef(FunctionalInterface)
				interface = true
				members += monitorTrigger.toMethod("accept", typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"), [
					static = false
					^default = false
					abstract = true
					visibility = JvmVisibility.PUBLIC
					monitorTrigger.params.parameters.forEach [ p |
						parameters += monitorTrigger.toParameter(p.name, p.parameterType)
					]
				])
			]
		)

		acceptor.accept(
			consumableFunctionalInterface
		)

		val containingEvent = findFirstAncestorOfType(monitorTrigger, Event)
		val JvmGenericType eventClass = containingEvent
										.jvmElements
										.filter(JvmGenericType)
										.filter[t | t.superTypes.map[st | st.qualifiedName].exists[s | s.equals("mt.edu.um.cs.rv.events.Event")]]
										.head
		val JvmGenericType eventBuilderClass = containingEvent
										.jvmElements
										.filter(JvmGenericType)
										.filter[t | t.superTypes.map[st | st.qualifiedName].forall[s | !s.equals("mt.edu.um.cs.rv.events.Event")]]
										.head
		
		val monitorTriggerClass = monitorTrigger.toClass(
			className,
			[
				superTypes += typeRef(functionalInterfaceName)
				
				members += monitorTrigger.toMethod("accept", typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					monitorTrigger.params.parameters.forEach [ p |
						parameters += monitorTrigger.toParameter(p.name, p.parameterType)
					]
					body = 
					'''				
					«eventBuilderClass.qualifiedName» eventBuilder = new «eventBuilderClass.qualifiedName»();
					
					//for all event parameters
					«FOR param : containingEvent.eventFormalParameters.parameters»
						eventBuilder.set«param.name.toFirstUpper»(
							build«param.name.toFirstUpper»(«monitorTrigger.params.parameters.stream.map[p | p.name].collect(Collectors.joining(", "))»)
						);
					«ENDFOR»
					
					//build the event and mark it as a synchronous event
					«eventClass.qualifiedName» event = eventBuilder.build(true);
					
					if 	(
							shouldFireEvent
							(
								«containingEvent.eventFormalParameters.parameters.stream.map[p | "event.get" + p.name.toFirstUpper + "()"].collect(Collectors.joining(", "))»
							)
						) 
						{
							return this.fireEvent(event);
						}
					else {
						return mt.edu.um.cs.rv.monitors.results.MonitorResult.ok(); 
					}
						
					'''
				])
				
				members += monitorTrigger.toMethod("fireEvent", typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"),[
					static = false
					visibility = JvmVisibility.PRIVATE
					parameters += monitorTrigger.toParameter("event", typeRef("mt.edu.um.cs.rv.events.Event"))
					
					body = 
					'''
					mt.edu.um.cs.rv.eventmanager.observers.DirectInvocationEventObserver observer = mt.edu.um.cs.rv.eventmanager.observers.DirectInvocationEventObserver.getInstance();
					
					java.util.concurrent.Future<mt.edu.um.cs.rv.monitors.results.MonitorResult<?>> monitorResultFuture = observer.observeEvent(event);
					try {
						return monitorResultFuture.get();
					} catch (InterruptedException ex) {
					    //TODO LOGGER.error("InterruptedException while getting monitor result", ex);
					    return MonitorResult.failure(null, ex);
					} catch (Throwable t) {
					    //TOOD LOGGER.error("Unexpected Throwable while getting monitor result", t);
					    return MonitorResult.failure(null, t);
					}
					'''	
				]
				)
				
				members += monitorTrigger.toMethod("shouldFireEvent", typeRef(boolean),[
					static = false
					visibility = JvmVisibility.PRIVATE
					containingEvent.eventFormalParameters.parameters.forEach [ p |
						parameters += monitorTrigger.toParameter(p.name, p.parameterType)
					]
					//default implementation is to return true, otherwise this will be overridden by the when clause
					body = 
					'''
					return true;
					'''	
				]
				)
			]
		)
		
		containingEvent.eventFormalParameters.parameters.forEach[ ep |
			monitorTriggerClass.members += 
				monitorTrigger.toMethod("build"+ep.name.toFirstUpper, 
					ep.parameterType,
					[
						static = false
						visibility = JvmVisibility.PRIVATE
						//add all available parameters to the method
						monitorTrigger.params.parameters.forEach [ p |
							parameters += monitorTrigger.toParameter(p.name, p.parameterType)
						]		
						
						//this is the default implementation, if a where is defined, it will be overridden once the where declaration is processed
						body = '''return «ep.name»;'''
					]
				)
		]

		acceptor.accept(
			monitorTriggerClass
		)
	}
	
	override handleExternaTrigger(ExternalTrigger externalTrigger, Boolean additionalTrigger){
		val packageName = packageNameToUse(externalTrigger) + ".events.builders"
		val containingEvent = findFirstAncestorOfType(externalTrigger, Event)
		val eventClass = containingEvent
								.jvmElements
								.filter(JvmGenericType)
								.filter[t | t.superTypes.map[st | st.qualifiedName].contains("mt.edu.um.cs.rv.events.Event") ]
								.head
								
		val eventBuilderClass = containingEvent
								.jvmElements
								.filter(JvmGenericType)
								.filter[t | t.superTypes.map[st | st.qualifiedName].forall[s | !s.equals("mt.edu.um.cs.rv.events.Event")]]
								.head


		val builderName = String.join("_", containingEvent.name.toFirstUpper, externalTrigger.triggerClass.simpleName, externalTrigger.dataClass.simpleName)
		val String className = packageName + ".EventBuilder" + (builderName)
		
		val externalEventBuilderClass = externalTrigger.toClass(
			className,
			[
				annotations += annotationRef("org.springframework.stereotype.Component")
				
				superTypes += typeRef("mt.edu.um.cs.rv.events.builders.EventBuilder", externalTrigger.dataClass, typeRef(eventClass))
				
				members += externalTrigger.toMethod("forEvent", typeRef(Class, typeRef(eventClass)), [
					static = false
					^default = false
					abstract = false
					visibility = JvmVisibility.PUBLIC
					body = '''return «eventClass.qualifiedName».class;'''
				])
				members += externalTrigger.toMethod("forTrigger", typeRef(Class, externalTrigger.dataClass), [
					static = false
					^default = false
					abstract = false
					visibility = JvmVisibility.PUBLIC
					body = '''return «externalTrigger.dataClass.qualifiedName».class;'''
				])
				members += externalTrigger.toMethod("build", typeRef(eventClass), [
					static = false
					^default = false
					abstract = false
					visibility = JvmVisibility.PUBLIC
					parameters += externalTrigger.toParameter(externalTrigger.dataClassVariable, externalTrigger.dataClass)
					parameters += externalTrigger.toParameter("synchronous", typeRef(Boolean))
					body = '''
						//create event builder
						«eventBuilderClass.qualifiedName» eventBuilder = new «eventBuilderClass.qualifiedName»();

						//for all event parameters
						«FOR param : containingEvent.eventFormalParameters.parameters»
							eventBuilder.set«param.name.toFirstUpper»(build«param.name.toFirstUpper»(«externalTrigger.dataClassVariable»));
						«ENDFOR»
						«eventClass.qualifiedName» event = eventBuilder.build();
						event.setSynchronous(synchronous);
						return event;
					'''
				])
				members += externalTrigger.toMethod("shouldFireEvent", typeRef(Boolean), [
					static = false
					^default = false
					abstract = false
					visibility = JvmVisibility.PUBLIC
					parameters += externalTrigger.toParameter("e", typeRef(eventClass))
					body = '''
						return _shouldFireEvent(«containingEvent.eventFormalParameters.parameters.stream.map[p | "e.get" + p.name.toFirstUpper + "()"].collect(Collectors.joining(", "))»);
					'''
				])
				members += externalTrigger.toMethod("_shouldFireEvent", typeRef(Boolean), [
					static = false
					^default = false
					abstract = false
					visibility = JvmVisibility.PRIVATE
					containingEvent.eventFormalParameters.parameters.forEach [ p |
						parameters += externalTrigger.toParameter(p.name, p.parameterType)
					]
					
					//if event declaration has a when block
					val whenClause = containingEvent.eventBody.when
					if ((whenClause != null) && (whenClause.condition != null) && (whenClause.condition.block != null)){
						if (whenClause.condition.block.simple != null){
							body = whenClause.condition.block.simple	
						} else {
							body = whenClause.condition.block.complex
						}
					}
					else {
						body = '''return true;'''
					}
				])
				
				containingEvent.eventFormalParameters.parameters.forEach[ ep |
					members += 
						externalTrigger.toMethod("build"+ep.name.toFirstUpper, 
							ep.parameterType,
							[
								static = false
								visibility = JvmVisibility.PRIVATE
								//add all available parameters to the method
								parameters += externalTrigger.toParameter(externalTrigger.dataClassVariable, externalTrigger.dataClass)
								
								//this is the default implementation, if a where is defined, it will be overridden once the where declaration is processed
								body = '''return «externalTrigger.dataClassVariable»;'''
							]
						)
				]
			]
		)

		acceptor.accept(
			externalEventBuilderClass
		)
		
	}

	override handleWhereClausesStart(WhereClauses whereClauses) {
	}

	override handleWhereClausesEnd(WhereClauses whereClauses) {
	}

	override handleWhereClause(WhereClause whereClause) {
		val containingEvent = findFirstAncestorOfType(whereClause, Event)
		
		//for each monitor trigger, override the declaration of the buildX() method with the where declaration
		val buildMethodName = "build" + whereClause.whereId.toFirstUpper
		var trigger = containingEvent.eventBody.trigger
		var additionalTrigger = containingEvent.eventBody.additionalTrigger 
		while (trigger != null)
		{
			//NOTE: assumes that the where declaration references a valid event parameters
			
			//TODO handle other types of triggers as necessary
			var JvmOperation buildMethod = null
			if ((trigger.monitorTrigger != null) || (trigger.externalTrigger != null)){
				
				if (trigger.monitorTrigger != null) {
					buildMethod = trigger.monitorTrigger
						.jvmElements
						.filter(JvmOperation)
						.filter [ op |
							op.simpleName.equals(buildMethodName)
						].head	
				} 
				
				if (trigger.externalTrigger != null) {
					buildMethod = trigger.externalTrigger
						.jvmElements
						.filter(JvmOperation)
						.filter [ op |
							op.simpleName.equals(buildMethodName)
						].head	
				}
				
				//TODO fix the order of this block, this if should be on the outside for performance reasons
				if (whereClause.whereExpression != null){
					if (whereClause.whereExpression.simple != null){
						buildMethod.body = whereClause.whereExpression.simple	
					} else {
						buildMethod.body = whereClause.whereExpression.complex
					}
				}

			} 
			
			//last step is to handle additional triggers
			trigger = null
			if (additionalTrigger != null){
				trigger = additionalTrigger.trigger	
			}
		}
	}

	override handleWhenClauseStart(WhenClause whenClause) {
		val containingEvent = findFirstAncestorOfType(whenClause, Event)
		
		//for each trigger, override the shouldFireEvent method
		var trigger = containingEvent.eventBody.trigger
		var additionalTrigger = containingEvent.eventBody.additionalTrigger 
		while (trigger != null)
		{	
			//TODO handle other types of triggers as necessary
			if (trigger.monitorTrigger != null){
				val buildMethod = trigger.monitorTrigger
					.jvmElements
					.filter(JvmOperation)
					.filter [ op |
						op.simpleName.equals("shouldFireEvent")
					].head
				
				
				if ((whenClause.condition != null) && (whenClause.condition.block != null)){
					if (whenClause.condition.block.simple != null){
						buildMethod.body = whenClause.condition.block.simple	
					} else {
						buildMethod.body = whenClause.condition.block.complex
					}
				}

			} 
			
			//last step is to handle additional triggers
			trigger = null
			if (additionalTrigger != null){
				trigger = additionalTrigger.trigger	
			}
		}
	}

	override handleWhenClauseEnd(WhenClause whenClause) {
	}

	override handleWhenClauseExpression(WhenClause clause) {
	}

	override handleCategorisationClauseStart(CategorisationClause categorisationClause) {
	}

	override handleCategorisationClauseExpression(CategorisationClause categorisationClause) {
	}

	override handleCategorisationClauseEnd(CategorisationClause categorisationClause) {
	}

	override handleConditionDeclarationStart(Condition condition) {
	}

	override handleConditionDeclarationExpression(Condition condition) {
		val packageName = packageNameToUse(condition) + ".conditions"
		val conditionId = conditionCounter++
		val String className = packageName + ".Condition" + (conditionId)
		val String functionalInterfaceName = packageName + ".ICondition" + (conditionId)

		val functionalInterface = condition.toClass(
			functionalInterfaceName,
			[
				annotations += annotationRef(FunctionalInterface)
				interface = true
				members += condition.toMethod("apply", typeRef(boolean), [
					static = false
					^default = false
					abstract = true
					visibility = JvmVisibility.PUBLIC
					condition.conditionFormalParameters.parameters.forEach [ p |
						parameters += condition.toParameter(p.name, p.parameterType)
					]
				])
			]
		)

		acceptor.accept(
			functionalInterface
		)

		val conditionClass = condition.toClass(
			className,
			[
				superTypes += typeRef(functionalInterfaceName)

				members += condition.toMethod("apply", typeRef(boolean), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					condition.conditionFormalParameters.parameters.forEach [ p |
						parameters += condition.toParameter(p.name, p.parameterType)
					]

					if (condition.conditionExpression.ref != null) {
						body = condition.conditionExpression.ref
					} else if (condition.conditionExpression.block.simple != null) {
						body = condition.conditionExpression.block.simple
					} else {
						body = condition.conditionExpression.block.complex
					}
				])
			]
		)

		acceptor.accept(
			conditionClass
		)
	}

	override handleConditionDeclarationEnd(Condition condition) {
	}

	override handleActionDeclarationStart(Action action) {
	}

	override handleActionDeclarationActionBlock(Action action) {
		
		val packageName = packageNameToUse(action) + ".actions"
		val actionId = actionCounter++
		val String className = packageName + ".Action" + (actionId)
		val String functionalInterfaceName = packageName + ".IAction" + (actionId)
		 
		val consumableFunctionalInterface = action.toClass(
			functionalInterfaceName,
			[
				annotations += annotationRef(FunctionalInterface)
				interface = true
				members += action.toMethod("accept", typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"), [
					static = false
					^default = false
					abstract = true
					visibility = JvmVisibility.PUBLIC
					action.actionFormalParameters.parameters.forEach [ p |
						parameters += action.toParameter(p.name, p.parameterType)
					]
				])
			]
		)

		acceptor.accept(
			consumableFunctionalInterface
		)

		val actionClass = action.toClass(
			className,
			[
				superTypes += typeRef(functionalInterfaceName)

				members += action.toMethod("accept", typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					action.actionFormalParameters.parameters.forEach [ p |
						parameters += action.toParameter(p.name, p.parameterType)
					]
					//if the action is not returning a returning a result, then we need to wrap
					if (action.isVoid != null) {
						body = '''
							this._accept(
								«action.actionFormalParameters.parameters.stream.map[p | p.name].collect(Collectors.joining(", "))»
							);
							return mt.edu.um.cs.rv.monitors.results.MonitorResult.ok();
						'''
					}
					//otherwise just use the action's body
					else {
						body = action.action
					}
				])
				
				//if the action is not returning a returning a result, then we need to wrap
				if (action.isVoid != null) { 
					members += action.toMethod("_accept", typeRef(void), [
						static = false
						visibility = JvmVisibility.PRIVATE
						action.actionFormalParameters.parameters.forEach [ p |
							parameters += action.toParameter(p.name, p.parameterType)
						]
						body = action.action
					])	
				}
				
				
			]
		)

		acceptor.accept(
			actionClass
		)
	}

	override handleActionDeclarationEnd(Action action) {
	}

	override handleRuleStart(Rule rule) {
	}

	override handleBasicRule(BasicRule basicRule) {
		var ruleWithoutBodyAndCondition = basicRule.event.eventRefId.name + "(" +
			actualParametersAsString(basicRule.event.eventActualParameters) + ") "

		if (basicRule.condition != null) {
			ruleWithoutBodyAndCondition = ruleWithoutBodyAndCondition + ' | { .. } '
		}

		ruleWithoutBodyAndCondition = ruleWithoutBodyAndCondition + ' -> { .. }'

		val packageName = packageNameToUse(basicRule) + ".monitors"
		val monitorIndex = monitorCounter++;
		val String className = packageName + ".Monitor" + monitorIndex

		val eventClass = basicRule.event.eventRefId
										.jvmElements
										.filter(JvmGenericType)
										.filter[t | t.superTypes.map[st | st.qualifiedName].contains("mt.edu.um.cs.rv.events.Event") ]
										.head

		if (eventClass == null) {
			// TODO error nicely
			println("WWWWWAAAAAAAAAAAAAAAA")
			return
		}

		val toStringBody = ruleWithoutBodyAndCondition

		// find the state class associated to this rule
		val valourBody = findFirstAncestorOfType(basicRule, ValourBody)
		val valourBodyContainer = valourBody.eContainer
		
		
		val JvmGenericType stateClass = valourBodyContainer.jvmElements
											.filter(JvmGenericType)
											.filter[c | c.simpleName.contains("State") && !c.simpleName.contains("Monitor")]
											.head

		var JvmGenericType monitorClass = basicRule.toClass(className, [
			static = false
			if (stateClass != null) {
				superTypes += typeRef("mt.edu.um.cs.rv.monitors.Monitor", typeRef(stateClass))
			}
			else {
				superTypes += typeRef("mt.edu.um.cs.rv.monitors.Monitor")
			}
			
	
			val Set<String> allParamNames = newHashSet()
			val List<Pair<String, JvmTypeReference>> allParams = newArrayList()
			val List<String> allActualParams = newArrayList()
			basicRule.event.eventRefId.eventFormalParameters.parameters.forEach [ eventParam |
				if (!allParamNames.contains(eventParam.name)) {
					allParams.add(new Pair<String, JvmTypeReference>(eventParam.name, eventParam.parameterType))
					allParamNames.add(eventParam.name)
					allActualParams.add("e.get" + eventParam.name.toFirstUpper + "()")
				}
			]
			
			if (stateClass != null) {
				allParams.add(new Pair<String, JvmTypeReference>("state", typeRef(stateClass)))
				allParamNames.add("state")
				allActualParams.add("state")
			}
			
//			stateClass.allFeatures
//				.filter(JvmField)
//				.filter[field | field.simpleName != "parentState"]
//				.forEach[ field |
//				if (!allParamNames.contains(field.simpleName)) {
//					allParams.add(new Pair<String, JvmTypeReference>(field.simpleName, field.type))
//					allParamNames.add(field.simpleName)
//					allActualParams.add("s." + field.simpleName)
//				}
//			]

//			if (!isTopLevelRule(basicRule)) {
//				members += basicRule.toField(
//					"state",
//					typeRef(stateClass),
//					[
//						visibility = JvmVisibility.PUBLIC
//						final = true
//					]
//				)
//			}

//			members += basicRule.toConstructor [
//				visibility = JvmVisibility.PUBLIC
//				if (!isTopLevelRule(basicRule)) {
//					parameters += basicRule.toParameter("state", typeRef(stateClass))
//					body = '''this.state = state;'''
//				}
//			]

			members += basicRule.toMethod(
				"requiredEvents",
				// Set<Class<? extends Event>> requiredEvents();
				typeRef(Set, typeRef(Class, wildcardExtends(typeRef("mt.edu.um.cs.rv.events.Event")))),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					body = '''return java.util.Collections.singleton(«eventClass.fullyQualifiedName».class);'''
				]
			)

			members += basicRule.toMethod(
				"getName",
				typeRef(String),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					body = '''return this.toString();'''
				]
			)

			members += basicRule.toMethod(
				"evaluateCondition",
				typeRef(boolean),
				[
					static = false
					visibility = JvmVisibility.PRIVATE
					parameters += basicRule.toParameter("e", typeRef(eventClass))
					if (stateClass != null) {
						parameters += basicRule.toParameter("state", typeRef(stateClass))
					}
					else {
						parameters += basicRule.toParameter("state", typeRef("mt.edu.um.cs.rv.monitors.state.State"))
					}

					body = '''
						return this._evaluateCondition(
							«allActualParams.stream.collect(Collectors.joining(", "))»
						);
					'''
				]
			)
			
			members += basicRule.toMethod(
				"_evaluateCondition",
				typeRef(boolean),
				[
					static = false
					visibility = JvmVisibility.PRIVATE
//					basicRule.event.eventRefId.eventFormalParameters.parameters.forEach [ p |
//						parameters += basicRule.toParameter(p.name, p.parameterType)
//					]
					allParams.forEach[p| parameters += basicRule.toParameter(p.key, p.value)]

					if (basicRule.condition == null){
						// if no condition has been specified, then return true
						body = '''return true;'''
					} else if ((basicRule.condition.block != null) && (basicRule.condition.block.simple != null)) { 
						body = basicRule.condition.block.simple
					} else if ((basicRule.condition.block != null) && (basicRule.condition.block.complex != null)) {
						body = basicRule.condition.block.complex
					} else if (basicRule.condition.ref != null) {
						body = basicRule.condition.ref							
					} 
				]
			)
		
			
			members += basicRule.toMethod(
				"performEventActions",
				typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"),
				[
					static = false
					visibility = JvmVisibility.PRIVATE
					parameters += basicRule.toParameter("e", typeRef(eventClass))
					if (stateClass != null) {
						parameters += basicRule.toParameter("state", typeRef(stateClass))
					}
					else {
						parameters += basicRule.toParameter("state", typeRef("mt.edu.um.cs.rv.monitors.state.State"))
					}

					body = '''
						return this._performEventActions(
							«allActualParams.stream.collect(Collectors.joining(", "))»
						);
					'''	
				]
			)
			
		
			members += basicRule.toMethod(
				"_performEventActions",
				typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"),
				[
					static = false
					visibility = JvmVisibility.PRIVATE
//					basicRule.event.eventRefId.eventFormalParameters.parameters.forEach [ p |
//						parameters += basicRule.toParameter(p.name, p.parameterType)
//					]
					allParams.forEach[p| parameters += basicRule.toParameter(p.key, p.value)]
						
					if (basicRule.ruleAction.actionBlock != null) {
						body = basicRule.ruleAction.actionBlock
					} else if (basicRule.ruleAction.actionRefInvocation != null) {
						body = basicRule.ruleAction.actionRefInvocation
					} else if (basicRule.ruleAction.actionMonitorTriggerFire != null) {
						body = basicRule.ruleAction.actionMonitorTriggerFire
					}
				]
			)								

			members += basicRule.toMethod(
				"handleEvent",
				typeRef("mt.edu.um.cs.rv.monitors.results.MonitorResult"),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					parameters += basicRule.toParameter("e", typeRef("mt.edu.um.cs.rv.events.Event"))
					if (stateClass != null) {
						parameters += basicRule.toParameter("s", typeRef(stateClass))
					}
					else {
						parameters += basicRule.toParameter("s", typeRef("mt.edu.um.cs.rv.monitors.state.State"))
					}
					body = '''
						if (e instanceof «eventClass.qualifiedName») {
							«eventClass.qualifiedName» event = («eventClass.qualifiedName») e;
							if (evaluateCondition(event, s)) {
								return this.performEventActions(event, s);
							}
							else {
								//TODO should we return a skipped status here?
								return mt.edu.um.cs.rv.monitors.results.MonitorResult.ok();
							}
						}
						else {
							//TODO this should never happen
							//TODO handle this cleanly ??
							throw new RuntimeException("Unable to handle event of type " + e.getClass().getName());
						}
					'''
				]
			)

			members += basicRule.toMethod(
				"toString",
				typeRef(String),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					// TODO clean this 
					body = '''return "«toStringBody»";'''
				]
			)

		])

		if (monitorClass != null) {
			acceptor.accept(
				monitorClass
			)
		} else {
			// TODO log error
			println("Unable to create monitor class!")
		}

		handleBasicRuleMonitorRegistration(basicRule, monitorClass, eventClass)
		
	}

	def isTopLevelRule(BasicRule rule){
		return isTopLevelEObject(rule)
	}
	
	def isTopLevelStateBlock(StateBlock stateBlock){
		return isTopLevelEObject(stateBlock)
	}
	
	def isTopLevelForEach(ForEach forEach){
		return isTopLevelEObject(forEach)
	}
	
	/**
	 * Checks whether the supplied eObject is a top level declaration 
	 * i.e. is declared in the top-most ValourBody.
	 * 
	 * @returns true if so, false if not
	 * @throws IllegalStateException if the provided eObject is not contained within at least one ValourBody
	 */
	def isTopLevelEObject(EObject eObject){
		val valourBody = findFirstAncestorOfType(eObject, ValourBody)
		
		if (valourBody == null) {
			throw new IllegalStateException("Provided eObject is not contained within at least one ValourBody")
		}
		
		val valourBodyContainer = valourBody.eContainer
		//get the ValourBody container of the ValourBody container of the BasicRule
		val parentValourBody = findFirstAncestorOfType(valourBodyContainer, ValourBody)
		//then BasicRule is top level rule and needs to be registered with the MonitorRegistry
		return parentValourBody == null
	}

	def handleBasicRuleMonitorRegistration(BasicRule basicRule, JvmGenericType monitorClass, JvmGenericType eventClass) {
		
		if (isTopLevelRule(basicRule)){
			topLevelRules.add(basicRule)
		}
		// if BasicRule is part of a State/ForEach block, then we need to build a delegate class
		else{
			// add the event to this block and all the upper blocks to ensure event registration
			requiredEventsStack.forEach[e|e.add(eventClass.fullyQualifiedName.toString)]

			// add the event to monitor association
			eventMonitorsStack.peek.put(eventClass.fullyQualifiedName.toString,
				monitorClass.fullyQualifiedName.toString)
		}
		
	}
	
	def handleStateBlockMonitorRegistration(StateBlock stateBlock, String monitorClassName, Set<String> events) {
		
		if (isTopLevelStateBlock(stateBlock)){
			topLevelRules.add(stateBlock)
		}
		// if BasicRule is part of a State/ForEach block, then we need to build a delegate class
		else{
			// add the event to monitor association
			events.forEach[e | 
				eventMonitorsStack.peek.put(e, monitorClassName)	
			]
		}
		
	}
	
	def handleForEachMonitorRegistration(ForEach forEach, String monitorClassName, Set<String> events) {
		
		if (isTopLevelForEach(forEach)){
			topLevelRules.add(forEach)
		}
		// if BasicRule is part of a State/ForEach block, then we need to build a delegate class
		else{
			// add the event to monitor association
			events.forEach[e | 
				eventMonitorsStack.peek.put(e, monitorClassName)	
			]
		}
		
	}
	
	

	override handleRuleEnd(Rule rule) {
	}

	override handleStateBlockStart(StateBlock stateBlock) {
		requiredEventsStack.push(new HashSet())
		eventMonitorsStack.push(ArrayListMultimap.create())
		
		val packageName = packageNameToUse(stateBlock) + ".state"
		val stateIndex = stateCounter++;

		val String stateClassName = packageName + ".State" + stateIndex

		val parentStateClass = getParentStateClassIfExists(stateBlock)
		val JvmGenericType stateClass = stateBlock.toClass(
			stateClassName,
			[
				static = false
				if (parentStateClass != null) {
					superTypes += typeRef("mt.edu.um.cs.rv.monitors.state.State", parentStateClass)
				}
				else {
					superTypes += typeRef("mt.edu.um.cs.rv.monitors.state.State")	
				}
				stateBlock.stateDec.forEach [ s |

					members += stateBlock.toField(
						s.name,
						s.type,
						[
							visibility = JvmVisibility.PUBLIC
							if (s.valueExpression.simple != null) {
								initializer = s.valueExpression.simple
							} else {
								initializer = s.valueExpression.complex
							}
						]
					)

				]

			]
		)
		
		acceptor.accept(
			stateClass
		)
		
		
		//create the monitor to be used to delegate events to monitors declared within
		val stateDelegatingMonitorPackage = packageNameToUse(stateBlock) + ".monitors.state" 
		val String stateDelegatingMonitorClassName = stateDelegatingMonitorPackage + ".StateDelegatingMonitor" + stateIndex
		val JvmGenericType stateDelegatingMonitorClass = stateBlock.toClass(
			stateDelegatingMonitorClassName,
			[
				static = false
				superTypes += typeRef("mt.edu.um.cs.rv.monitors.StatefulMonitor")
				
				members += stateBlock.toMethod(
					"initialiseRequiredEvents",
					typeRef(void),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						// setting the body to empty, this is then set in handleStateBlockEnd() using the content of monitorEventRequirementsStack
						body = ''''''
					]
				)
				
				members += stateBlock.toMethod(
					"initialiseInterestedMonitorTypesForEvent",
					typeRef(void),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						// setting the body to empty, this is then set in handleStateBlockEnd() using the content of monitorEventRequirementsStack
						body = ''''''
					]
				)
				
				members += stateBlock.toMethod(
					"initialiseNewState",
					typeRef(stateClass),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						body = '''
							try {
								return «stateClassName».class.newInstance();
							} catch (InstantiationException | IllegalAccessException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
								throw new RuntimeException("Unable to create new state instance of «stateClassName»");
							}
						'''
					]
				)
			
				members += stateBlock.toMethod(
					"getName",
					typeRef(String),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						body = '''return this.toString();'''
					]
				)

				members += stateBlock.toMethod(
					"toString",
					typeRef(String),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						body = '''return "«stateDelegatingMonitorClassName»";'''
					]
				)
			]
		)

		acceptor.accept(
			stateDelegatingMonitorClass
		)
	}

	def JvmTypeReference getParentStateClassIfExists(EObject context) {
		val containingRule = findFirstAncestorOfType(context, Rule)
		val parentRule = findParentRule(containingRule)
		if (parentRule != null) {
			var JvmGenericType parentStateClass = null

			if (parentRule instanceof StateBlock) {
				val StateBlock sb = parentRule as StateBlock
				parentStateClass = sb.jvmElements.filter(JvmGenericType).filter[t|t.simpleName.startsWith("State")].head
			} else if (parentRule instanceof ForEach) {
				val ForEach fe = parentRule as ForEach
				parentStateClass = fe.jvmElements.filter(JvmGenericType).filter[t|t.simpleName.startsWith("State")].head
			} else if (parentRule instanceof ParForEach) {
				// TODO	
			}

			if (parentStateClass != null) {
				return typeRef(parentStateClass)
			}
		}
		return null
	}

	override handleStateDeclaration(StateDeclaration sd) {
	}

	override handleStateBlockStateDeclarationsEnd(StateBlock block) {
		
	}

	override handleStateBlockEnd(StateBlock block) {
		val allEvents = requiredEventsStack.pop

		val eventMonitors = eventMonitorsStack.pop

		val initialiseRequiredEventsMethod = block.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("initialiseRequiredEvents")
		].head
		initialiseRequiredEventsMethod.body = '''
			//set all required events 
			«FOR e : allEvents»
				this.addRequiredEvent(«e».class);
			«ENDFOR»
		'''


		val initialiseInterestedMonitorTypesForEventMethod = block.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("initialiseInterestedMonitorTypesForEvent")
		].head
		initialiseInterestedMonitorTypesForEventMethod.body = '''
			//initialise map of events and the respective interested monitors
			java.util.List<Class<? extends mt.edu.um.cs.rv.monitors.Monitor>> list;			
			«FOR e : eventMonitors.keySet»
				list = new java.util.ArrayList();
				«FOR m : eventMonitors.get(e)»
					//prepare the list for the interestedMonitorTypesForEvent map
					list.add(«m».class);
				«ENDFOR»
				
				this.addInterestedMonitorTypesForEvent(«e».class, list); 
			«ENDFOR»
		'''
		
		val monitorClass = block.jvmElements.filter(JvmGenericType).filter [ c |
			c.simpleName.contains("StateDelegatingMonitor")
		].head
		
		handleStateBlockMonitorRegistration(block, monitorClass.fullyQualifiedName.toString, allEvents)
	}

	override handleForEachBlockStart(ForEach forEach) {
		val basePackageName = packageNameToUse(forEach)
		val packageName = basePackageName + ".monitors.foreach"

		val String className = packageName + ".ForEachDelegatingMonitor" + (monitorCounter++)
		val String stateClassName = basePackageName + ".state.State" + (stateCounter++)

		val keyType = forEach.category.category.keyType

		requiredEventsStack.push(new HashSet())

		eventMonitorsStack.push(ArrayListMultimap.create())

		// create the state class
		val parentStateClass = getParentStateClassIfExists(forEach)
		val JvmGenericType forEachStateClass = forEach.toClass(
			stateClassName,
			[
				static = false
				if (parentStateClass != null) {
					superTypes += typeRef("mt.edu.um.cs.rv.monitors.state.State", parentStateClass)
				}
				else {
					superTypes += typeRef("mt.edu.um.cs.rv.monitors.state.State")	
				}
				forEach.stateDec.forEach [ s |

					members += forEach.toField(
						s.name,
						s.type,
						[
							visibility = JvmVisibility.PUBLIC
							if (s.valueExpression.simple != null) {
								initializer = s.valueExpression.simple
							} else {
								initializer = s.valueExpression.complex
							}
						]
					)

				]

			]
		)

		acceptor.accept(
			forEachStateClass
		)

		var JvmGenericType forEachDelegatingMonitorClass = forEach.toClass(
			className,
			[
				static = false
				superTypes += typeRef("mt.edu.um.cs.rv.monitors.CategorisedStatefulMonitor", typeRef(forEachStateClass))
				
				members += forEach.toMethod(
					"initialiseRequiredEvents",
					typeRef(void),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						// setting the body to empty, this is then set in handleForEachBlockEnd() using the content of monitorEventRequirementsStack
						body = ''''''
					]
				)
				
				members += forEach.toMethod(
					"initialiseInterestedMonitorTypesForEvent",
					typeRef(void),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						// setting the body to empty, this is then set in handleForEachBlockEnd() using the content of monitorEventRequirementsStack
						body = ''''''
					]
				)
				
				members += forEach.toMethod(
					"initialiseNewState",
					typeRef(forEachStateClass),
					[
						static = false
						visibility = JvmVisibility.PROTECTED
						annotations += annotationRef(Override)
						body = '''
							try {
								return «forEachStateClass».class.newInstance();
							} catch (InstantiationException | IllegalAccessException e) {
								// TODO Auto-generated catch block
								e.printStackTrace();
								throw new RuntimeException("Unable to create new state instance of «stateClassName»");
							}
						'''
					]
				)
			
				members += forEach.toMethod(
					"getName",
					typeRef(String),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						body = '''return this.toString();'''
					]
				)

				members += forEach.toMethod(
					"toString",
					typeRef(String),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						body = '''return "«className»";'''
					]
				)
			]
		)

		acceptor.accept(
			forEachDelegatingMonitorClass
		)

	}

	override handleForEachCategoryDefinitionStart(ForEach forEach) {
	}

	override handleForEachBlockEnd(ForEach forEach) {
		val allEvents = requiredEventsStack.pop

		val eventMonitors = eventMonitorsStack.pop
		
		val initialiseRequiredEventsMethod = forEach.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("initialiseRequiredEvents")
		].head
		initialiseRequiredEventsMethod.body = '''
			//set all required events 
			«FOR e : allEvents»
				this.addRequiredEvent(«e».class);
			«ENDFOR»
		'''
		
		val initialiseInterestedMonitorTypesForEventMethod = forEach.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("initialiseInterestedMonitorTypesForEvent")
		].head
		initialiseInterestedMonitorTypesForEventMethod.body = '''
			//initialise map of events and the respective interested monitors
			java.util.List<Class<? extends mt.edu.um.cs.rv.monitors.Monitor>> list;			
			«FOR e : eventMonitors.keySet»
				list = new java.util.ArrayList();
				«FOR m : eventMonitors.get(e)»
					//prepare the list for the interestedMonitorTypesForEvent map
					list.add(«m».class);
				«ENDFOR»
				
				this.addInterestedMonitorTypesForEvent(«e».class, list); 
			«ENDFOR»
		'''
		
		val monitorClass = forEach.jvmElements.filter(JvmGenericType).filter[ c | 
			c.simpleName.contains("ForEachDelegatingMonitor")
		].head
		
		handleForEachMonitorRegistration(forEach, monitorClass.fullyQualifiedName.toString, allEvents)
	}

	override handleParForEachBlockStart(ParForEach parForEach) {
	}

	override handleParForEachCategoryDefinitionStart(ParForEach parForEach) {
	}

	override handleParForEachBlockEnd(ParForEach parForEach) {
	}
	
	override handleScriptEnd(Model model){
		
		val packageName = packageNameToUse(model) + ".config"
		val String className = packageName + ".MonitorConfig"
		
		val monitorRegistrationClass = model.toClass(
			className,
			[
				annotations += annotationRef("org.springframework.context.annotation.Configuration")
				annotations += model.toAnnotationRefWithStringPair(
					"org.springframework.context.annotation.ComponentScan",
					Pair.of("basePackages", (packageNameToUse(model) + ".events.builders"))
				)
				members += model.toField(
					"monitorRegistry", 
					typeRef("mt.edu.um.cs.rv.eventmanager.monitors.registry.MonitorRegistry"),
					[
						visibility = JvmVisibility.PRIVATE
						annotations += annotationRef("org.springframework.beans.factory.annotation.Autowired")
					]
				)
				
				members += model.toField(
					"monitorPersistenceProvider", 
					typeRef("mt.edu.um.cs.rv.monitors.persistence.MonitorPersistenceProvider"),
					[
						visibility = JvmVisibility.PRIVATE
						annotations += model.toAnnotationRefWithStringBooleanPair("org.springframework.beans.factory.annotation.Autowired", Pair.of("required", false))
					]
				)
				
				members += model.toMethod("init", typeRef(void), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef("javax.annotation.PostConstruct")
					body = 
					'''
						mt.edu.um.cs.rv.monitors.Monitor monitor;
						
						«FOR r : topLevelRules»
							«val JvmGenericType monitorClass = getMonitorClassFromEObject(r)»
							
							«IF (monitorClass != null)»
								monitor = new «monitorClass.qualifiedName»();
								if (monitor instanceof mt.edu.um.cs.rv.monitors.StatefulMonitor) {
									((mt.edu.um.cs.rv.monitors.StatefulMonitor) monitor).setMonitorPersistenceProvider(this.monitorPersistenceProvider);
								}
								this.monitorRegistry.registerNewMonitor(monitor);
							«ENDIF»
						«ENDFOR»
					'''
				])
			]
		)
		
		acceptor.accept(
			monitorRegistrationClass
		)
	}
	
	def getMonitorClassFromEObject(EObject e){
		e.jvmElements
			.filter(JvmGenericType)
			.filter[c | c.superTypes.size > 0]
			.filter[c | c.simpleName.contains("Monitor")]
//			.filter[c | c.superTypes.exists[t | t.equals(typeRef("mt.edu.um.cs.rv.monitors.Monitor"))]]
			.head
	}

}
