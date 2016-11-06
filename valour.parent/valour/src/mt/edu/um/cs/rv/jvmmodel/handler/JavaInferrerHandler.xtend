package mt.edu.um.cs.rv.jvmmodel.handler;

import javax.inject.Inject
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
import mt.edu.um.cs.rv.valour.WhenClause
import mt.edu.um.cs.rv.valour.WhereClause
import mt.edu.um.cs.rv.valour.WhereClauses
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.xbase.jvmmodel.JvmAnnotationReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmTypeReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder
import org.eclipse.xtext.xtype.XImportSection
import mt.edu.um.cs.rv.valour.ConditionRefInvocation
import java.util.Set
import java.util.concurrent.ForkJoinPool
import org.eclipse.xtext.xbase.XExpression
import mt.edu.um.cs.rv.utils.ValourScriptTraverser
import mt.edu.um.cs.rv.valour.ValourBody
import java.util.List
import java.util.Map
import org.eclipse.xtext.common.types.JvmOperation
import java.util.Stack
import org.eclipse.xtend2.lib.StringConcatenation
import com.google.common.collect.Multimap
import com.google.common.collect.ArrayListMultimap
import org.eclipse.xtext.xbase.lib.Procedures.Procedure1
import org.eclipse.xtext.xbase.compiler.output.ITreeAppendable
import java.util.HashSet
import com.google.common.collect.ListMultimap
import org.eclipse.xtext.common.types.JvmTypeReference

public class JavaInferrerHandler extends InferrerHandler {

	/**
	 * convenience API to build and initialize JVM types and their members.
	 */
	@Inject extension JvmTypesBuilder

	@Inject extension IJvmModelAssociations
	@Inject extension IQualifiedNameProvider

	@Inject extension ValourScriptTraverser

	var Model model
	var IJvmDeclaredTypeAcceptor acceptor

	var monitorCounter = 1;
	var eventCounter = 1;
	var actionCounter = 1;
	var conditionCounter = 1;
	var stateCounter = 1;

	@Extension JvmAnnotationReferenceBuilder _annotationTypesBuilder;
	@Extension JvmTypeReferenceBuilder _typeReferenceBuilder;

	Stack<Set<String>> requiredEventsStack = new Stack()
	Stack<Multimap<String, String>> eventMonitorsStack = new Stack()

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

		// TODO rename?
		val String scaffoldClassName = packageName + ".Scaffold"
		var JvmGenericType scaffoldClass = model.toClass(scaffoldClassName)
		scaffoldClass.members += model.toClass("Categories", [static = true])
		scaffoldClass.members += model.toClass("Conditions", [static = true])
		scaffoldClass.members += model.toClass("Actions", [static = true])

		acceptor.accept(
			scaffoldClass
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

		if (event.eventFormalParameters != null && !event.eventFormalParameters.parameters.isNullOrEmpty) {

			// generate a private field for each event parameter
			event.eventFormalParameters.parameters.forEach [ param |
				eventClass.members += event.toField(
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

			// generate a getter method for each event parameter
			event.eventFormalParameters.parameters.forEach [ param |
				eventClass.members += event.toGetter(
					param.name,
					param.parameterType
				)
			]
		}

		eventClass.members += event.toMethod(
			"isSynchronous",
			typeRef(Boolean.TYPE),
			[
				static = false
				visibility = JvmVisibility.PUBLIC
				annotations += annotationRef(Override)
				body = '''return true;'''
			]
		)

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
				members += monitorTrigger.toMethod("accept", typeRef(void), [
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
		val JvmGenericType eventClass = containingEvent.jvmElements.filter(JvmGenericType).head
		
		val monitorTriggerClass = monitorTrigger.toClass(
			className,
			[
				superTypes += typeRef(functionalInterfaceName)

				members += monitorTrigger.toMethod("accept", typeRef(void), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					monitorTrigger.params.parameters.forEach [ p |
						parameters += monitorTrigger.toParameter(p.name, p.parameterType)
					]
					body = 
					'''
					mt.edu.um.cs.rv.eventmanager.observers.DirectInvocationEventObserver observer = mt.edu.um.cs.rv.eventmanager.observers.DirectInvocationEventObserver.getInstance();
					
					//TODO handle event parameters
					«eventClass.qualifiedName» event = new «eventClass.qualifiedName»();
					
					observer.observeEvent(event);
					return;
					'''
				])
			]
		)

		acceptor.accept(
			monitorTriggerClass
		)
	}

	override handleWhereClausesStart(WhereClauses whereClauses) {
	}

	override handleWhereClausesEnd(WhereClauses whereClauses) {
	}

	override handleWhereClause(WhereClause whereClause) {
	}

	override handleWhenClauseStart(WhenClause whenClause) {
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
				members += action.toMethod("accept", typeRef(void), [
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

				members += action.toMethod("accept", typeRef(void), [
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					action.actionFormalParameters.parameters.forEach [ p |
						parameters += action.toParameter(p.name, p.parameterType)
					]
//					body = '''return;'''
					body = action.action
				])
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

		val eventClass = basicRule.event.eventRefId.getJvmElements().filter(JvmGenericType).head

		if (eventClass == null) {
			// TODO error nicely
			println("WWWWWAAAAAAAAAAAAAAAA")
			return
		}

		val toStringBody = ruleWithoutBodyAndCondition

		// find the state class associated to this rule
		val valourBody = findFirstAncestorOfType(basicRule, ValourBody)
		val valourBodyContainer = valourBody.eContainer
		// TODO add handler for ForEach and ParForEach
		val JvmGenericType stateClass = valourBodyContainer.jvmElements.filter(JvmGenericType).head

		var JvmGenericType monitorClass = basicRule.toClass(className, [
			static = false
			superTypes += typeRef("mt.edu.um.cs.rv.monitors.Monitor")

			members += basicRule.toField(
				"state",
				typeRef(stateClass),
				[
					visibility = JvmVisibility.PUBLIC
					final = true
				]
			)

			members += basicRule.toConstructor [
				visibility = JvmVisibility.PUBLIC
				parameters += basicRule.toParameter("state", typeRef(stateClass))
				body = '''this.state = state;'''
			]

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

					if (basicRule.condition != null) {
						if (basicRule.condition.ref != null) {
							body = basicRule.condition.ref
						} else if (basicRule.condition.block != null) {
							if (basicRule.condition.block.simple != null) {
								body = basicRule.condition.block.simple
							} else if (basicRule.condition.block.complex != null) {
								body = basicRule.condition.block.complex
							}
						}
					} else {
						// if no condition has been specified, then return true
						body = '''return true;'''
					}
				]
			)

			members += basicRule.toMethod(
				"performEventActions",
				typeRef(void),
				[
					static = false
					visibility = JvmVisibility.PRIVATE
					parameters += basicRule.toParameter("e", typeRef(eventClass))

					if (basicRule.ruleAction.actionBlock != null)
						body = basicRule.ruleAction.actionBlock
					else if (basicRule.ruleAction.actionRefInvocation != null) {
						body = basicRule.ruleAction.actionRefInvocation
					} else if (basicRule.ruleAction.actionMonitorTriggerFire != null) {
						// TODO - see issue #20
						body = '''System.out.println(e.toString());'''
					}
				]
			)

			members += basicRule.toMethod(
				"handleEvent",
				typeRef(void),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					parameters += basicRule.toParameter("e", typeRef("mt.edu.um.cs.rv.events.Event"))
					body = '''
						if (e instanceof «eventClass.qualifiedName») {
							«eventClass.qualifiedName» event = («eventClass.qualifiedName») e;
							if (evaluateCondition(event)) {
								this.performEventActions(event);
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

		handleRulePartOfForEach(basicRule, monitorIndex, monitorClass, eventClass)

	}

	def handleRulePartOfForEach(BasicRule basicRule, int monitorCounter, JvmGenericType monitorClass,
		JvmGenericType eventClass) {
		// if BasicRule is part of a ForEach block, then we need to build a delegate class
		val valourBody = findFirstAncestorOfType(basicRule, ValourBody)
		val valourBodyContainer = valourBody.eContainer
		if (valourBodyContainer instanceof ForEach) {
			// add the event to this block and all the upper blocks to ensure event registration
			requiredEventsStack.forEach[e|e.add(eventClass.fullyQualifiedName.toString)]

			// add the event to monitor association
			eventMonitorsStack.peek.put(eventClass.fullyQualifiedName.toString,
				monitorClass.fullyQualifiedName.toString)
		}

	}

	override handleRuleEnd(Rule rule) {
	}

	override handleStateBlockStart(StateBlock stateBlock) {
		val packageName = packageNameToUse(stateBlock) + ".state"
		val stateIndex = stateCounter++;

		val String className = packageName + ".State" + stateIndex

		val JvmGenericType stateClass = stateBlock.toClass(
			className,
			[
				static = false

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

		// check if class should have a parent field added to it
		addParentToStateClassIfRequired(stateBlock, stateClass)

		acceptor.accept(
			stateClass
		)
	}
	
	def JvmGenericType addParentToStateClassIfRequired(EObject context, JvmGenericType clazz){
		val containingRule = findFirstAncestorOfType(context, Rule)
		val parentRule = findParentRule(containingRule)
		if (parentRule != null) {
			var JvmGenericType parentStateClass = null

			if (parentRule instanceof StateBlock) {
				val StateBlock sb = parentRule as StateBlock
				parentStateClass = sb.jvmElements.filter(JvmGenericType).head
			}
			else if (parentRule instanceof ForEach) {
				val ForEach fe = parentRule as ForEach
				parentStateClass = fe.jvmElements.filter(JvmGenericType).filter[t | t.simpleName.startsWith("State")].head
			}
			else if (parentRule instanceof ParForEach) {
				// TODO	
			}

			if (parentStateClass != null) {
				clazz.members += context.toField(
					"parent",
					typeRef(parentStateClass),
					[
						visibility = JvmVisibility.PUBLIC
					]
				)
				
				return parentStateClass
			}
		}
		
		return null
				
	}

	override handleStateDeclaration(StateDeclaration sd) {
	}

	override handleStateBlockStateDeclarationsEnd(StateBlock block) {
	}

	override handleStateBlockEnd(StateBlock block) {
	}

	override handleForEachBlockStart(ForEach forEach) {
		val basePackageName = packageNameToUse(forEach) 
		val packageName = basePackageName + ".monitors.foreach"
		
		val String className = packageName + ".ForEachDelegatingMonitor" + (monitorCounter++)
		val String stateClassName = basePackageName + ".state.State" + (stateCounter++) 

		val keyType = forEach.category.category.keyType

		requiredEventsStack.push(new HashSet())

		eventMonitorsStack.push(ArrayListMultimap.create())
		
		//create the state class
		val JvmGenericType forEachStateClass = forEach.toClass(
			stateClassName,
			[
				static = false

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
		val parentStateClass = addParentToStateClassIfRequired(forEach, forEachStateClass)
		
		acceptor.accept(
			forEachStateClass
		)

		var JvmGenericType forEachDelegatingMonitorClass = forEach.toClass(
			className,
			[
				static = false
				superTypes += typeRef("mt.edu.um.cs.rv.monitors.Monitor")

				members += forEach.toMethod(
					"requiredEvents",
					// Set<Class<? extends Event>> requiredEvents();
					typeRef(Set, typeRef(Class, wildcardExtends(typeRef("mt.edu.um.cs.rv.events.Event")))),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						// setting the body to empty, this is then set in handleForEachBlockEnd() using the content of monitorEventRequirementsStack
						body = ''''''
					]
				)

				members += forEach.toMethod(
					"handleEvent",
					typeRef(void),
					[
						static = false
						visibility = JvmVisibility.PUBLIC
						annotations += annotationRef(Override)
						parameters += forEach.toParameter("e", typeRef("mt.edu.um.cs.rv.events.Event"))
						body = '''
							
							if (!(e instanceof mt.edu.um.cs.rv.events.CategorisedEvent)){
								//TODO handle this situation somehow
								throw new RuntimeException("Cannot handle an un-categorised event in a for-each construct");
							}
							
							mt.edu.um.cs.rv.events.CategorisedEvent ce = (mt.edu.um.cs.rv.events.CategorisedEvent) e;
							«keyType» key = («keyType») ce.categoriseEvent();
							
							if (e == null){
								//TODO this should never happen
								//TODO handle this cleanly ??
								throw new RuntimeException("Unable to handle event of type " + e.getClass().getName() + " as categorisation returned null");
							}
							else{
								
								List<Class<? extends mt.edu.um.cs.rv.monitors.Monitor>> interestedMonitorTypes = getInterestedMonitorTypes(e);
								
								for (Class<? extends mt.edu.um.cs.rv.monitors.Monitor> c : interestedMonitorTypes){
									java.util.Map<«keyType», mt.edu.um.cs.rv.monitors.Monitor> map = getLookupTable(c);
									
									mt.edu.um.cs.rv.monitors.Monitor monitor = map.get(key);
																			
									if (monitor == null){
										
										try {
											//create state object to be passed to the new monitor
											«IF (parentStateClass != null)»
												«forEachStateClass» newState = «forEachStateClass».class.newInstance();
												newState.parent = this.state;
											«ELSE»
												«forEachStateClass» newState = «forEachStateClass».class.newInstance();
											«ENDIF»
											
											//create new monitor with the given state object
											monitor = c.newInstance();
											c.getField("state").set(monitor, newState);
										} catch (InstantiationException | IllegalAccessException | IllegalArgumentException | NoSuchFieldException | SecurityException e1) {
											// TODO Auto-generated catch block
											e1.printStackTrace();
										}
										map.put(key, monitor);
									}
									
									monitor.handleEvent(e);
								}
							
							}
						'''
					]
				)

				members += forEach.toMethod(
					"getInterestedMonitorTypes",
					typeRef(List, typeRef(Class, wildcardExtends(typeRef("mt.edu.um.cs.rv.monitors.Monitor")))),
					[
						static = false
						visibility = JvmVisibility.PRIVATE
						parameters += forEach.toParameter("e", typeRef("mt.edu.um.cs.rv.events.Event"))
						body = '''
							//TODO 
							return new java.util.ArrayList();
						'''
					]
				)

				members += forEach.toField(
					"lookupTables",
					typeRef(Map, typeRef(Class), typeRef(Map, keyType, typeRef("mt.edu.um.cs.rv.monitors.Monitor"))),
					[
						visibility = JvmVisibility.PRIVATE
						val Procedure1<ITreeAppendable> b = [
							append('''new java.util.HashMap()''')
						]
						initializer = b
					]
				)

				members +=
					forEach.toMethod(
						"getLookupTable",
						typeRef(Map),
//						typeRef(Map, typeRef(keyType), typeRef("mt.edu.um.cs.rv.monitors.Monitor")),
						[
							static = false
							visibility = JvmVisibility.PRIVATE
							parameters +=
								forEach.toParameter("c",
									typeRef(Class, wildcardExtends(typeRef("mt.edu.um.cs.rv.monitors.Monitor"))))
							body = '''
								return lookupTables.get(c);
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
				
				if (parentStateClass != null){
					members += forEach.toField(
						"state",
						typeRef(parentStateClass),
						[
							visibility = JvmVisibility.PUBLIC
						]
					)
				}
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

		val requiredEventsMethod = forEach.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("requiredEvents")
		].head
		requiredEventsMethod.body = '''
			Set<Class<? extends mt.edu.um.cs.rv.events.Event>> s = new java.util.HashSet<>();
			
			«FOR e : allEvents»
				s.add(«e».class);
			«ENDFOR»
			
			return s;
		'''

		val eventMonitors = eventMonitorsStack.pop

		val getInterestedMonitorTypesMethod = forEach.jvmElements.filter(JvmOperation).filter [ op |
			op.simpleName.equals("getInterestedMonitorTypes")
		].head
		getInterestedMonitorTypesMethod.body = '''
			Map<Class, java.util.List<Class<? extends Monitor>>> map = new java.util.HashMap<>();
			java.util.List<Class<? extends Monitor>> list;
			
			«FOR e : eventMonitors.keySet»
				list = new java.util.ArrayList();
				«FOR m : eventMonitors.get(e)»
					list.add(«m».class);
				«ENDFOR»
				map.put(«e».class, list); 
				 
				
			«ENDFOR»
			
			return map.get(e);
		'''
	}

	override handleParForEachBlockStart(ParForEach parForEach) {
	}

	override handleParForEachCategoryDefinitionStart(ParForEach parForEach) {
	}

	override handleParForEachBlockEnd(ParForEach parForEach) {
	}

}
