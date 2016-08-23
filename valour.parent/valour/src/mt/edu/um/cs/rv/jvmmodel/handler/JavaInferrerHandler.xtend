package mt.edu.um.cs.rv.jvmmodel.handler;

import mt.edu.um.cs.rv.valour.Model
import org.eclipse.xtext.common.types.JvmGenericType
import javax.inject.Inject
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder
import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import org.eclipse.xtext.xtype.XImportSection
import mt.edu.um.cs.rv.valour.Category
import mt.edu.um.cs.rv.valour.Event
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.xbase.jvmmodel.JvmTypeReferenceBuilder
import org.eclipse.xtext.xbase.jvmmodel.JvmAnnotationReferenceBuilder
import mt.edu.um.cs.rv.valour.ControlFlowTrigger
import mt.edu.um.cs.rv.valour.EventTrigger
import mt.edu.um.cs.rv.valour.MonitorTrigger
import mt.edu.um.cs.rv.valour.WhereClauses
import mt.edu.um.cs.rv.valour.WhereClause
import mt.edu.um.cs.rv.valour.WhenClause
import mt.edu.um.cs.rv.valour.CategorisationClause
import mt.edu.um.cs.rv.valour.Condition
import mt.edu.um.cs.rv.valour.Action
import mt.edu.um.cs.rv.valour.Rule
import mt.edu.um.cs.rv.valour.BasicRule
import java.util.Set
import org.eclipse.xtext.xbase.jvmmodel.IJvmModelAssociations
import org.eclipse.xtext.naming.IQualifiedNameProvider
import mt.edu.um.cs.rv.valour.StateBlock
import mt.edu.um.cs.rv.valour.StateDeclaration
import mt.edu.um.cs.rv.valour.ForEach
import mt.edu.um.cs.rv.valour.ParForEach
import org.eclipse.emf.ecore.resource.Resource

public class JavaInferrerHandler extends InferrerHandler {
//
//	@Inject JvmAnnotationReferenceBuilder.Factory annotationRefBuilderFactory;
//	@Inject JvmTypeReferenceBuilder.Factory typeRefBuilderFactory;
	
//	@Extension JvmAnnotationReferenceBuilder _annotationTypesBuilder;
//	@Extension JvmTypeReferenceBuilder _typeReferenceBuilder;

	/**
	 * convenience API to build and initialize JVM types and their members.
	 */
	@Inject extension JvmTypesBuilder

//	@Inject extension JvmTypeReferenceBuilder
//	@Inject extension JvmAnnotationReferenceBuilder
	@Inject extension IJvmModelAssociations
	@Inject extension IQualifiedNameProvider
	
	var Model model
	var IJvmDeclaredTypeAcceptor acceptor

	var monitorCounter = 1;
	var eventCounter = 1;
	
	
//	@Inject JvmAnnotationReferenceBuilder.Factory annotationRefBuilderFactory;
//	@Inject JvmTypeReferenceBuilder.Factory typeRefBuilderFactory;
//	
	@Extension JvmAnnotationReferenceBuilder _annotationTypesBuilder;
	@Extension JvmTypeReferenceBuilder _typeReferenceBuilder;
	
	
	override void setup(JvmAnnotationReferenceBuilder _annotationTypesBuilder, JvmTypeReferenceBuilder _typeReferenceBuilder){
//	def void setContext(Resource resource) {
//		_annotationTypesBuilder = annotationRefBuilderFactory.create(resource.getResourceSet());
//		_typeReferenceBuilder = typeRefBuilderFactory.create(resource.getResourceSet());
		this._annotationTypesBuilder = _annotationTypesBuilder
		this._typeReferenceBuilder = _typeReferenceBuilder
	
	}

	override initialise(Model model, IJvmDeclaredTypeAcceptor acceptor) {

		this.model = model
		this.acceptor = acceptor

		// TODO the package to which to generate the classes should be defined in the language ???
		val packageName = packageNameToUse(model.eResource.URI.lastSegment)

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
	def String packageNameToUse(String inputFileName) {
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
		val packageName = packageNameToUse(event.eResource.URI.lastSegment) + ".events"
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
		
	}
	
	override handleConditionDeclarationEnd(Condition condition) {
		
	}
	
	override handleActionDeclarationStart(Action action) {
		
	}
	
	override handleActionDeclarationActionBlock(Action action) {
		
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

		val packageName = packageNameToUse(basicRule.eResource.URI.lastSegment) + ".monitors"
		val String className = packageName + ".Monitor" + (monitorCounter++)

		val eventClass = basicRule.event.eventRefId.getJvmElements().filter(JvmGenericType).head

		if (eventClass == null) {
			// TODO error nicely
			println("WWWWWAAAAAAAAAAAAAAAA")
			return
		}

		val toStringBody = ruleWithoutBodyAndCondition

		var JvmGenericType scaffoldClass = basicRule.toClass(className, [
			static = false
			superTypes += typeRef("mt.edu.um.cs.rv.monitors.Monitor")

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
				"handleEvent",
				typeRef(void),
				[
					static = false
					visibility = JvmVisibility.PUBLIC
					annotations += annotationRef(Override)
					parameters += basicRule.toParameter("e", typeRef("mt.edu.um.cs.rv.events.Event"))
					body = '''System.out.println(e.toString());'''
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

		if (scaffoldClass != null) {
			acceptor.accept(
				scaffoldClass
			)
		} else {
			// TODO log error
			println("Unable to create monitor class!")
		}

	}
	
	override handleRuleEnd(Rule rule) {
		
	}
	
	override handleStateBlockStart(StateBlock block) {
		
	}
	
	override handleStateDeclaration(StateDeclaration sd) {
		
	}
	
	override handleStateBlockStateDeclarationsEnd(StateBlock block) {
		
	}
	
	override handleStateBlockEnd(StateBlock block) {
		
	}
	
	override handleForEachBlockStart(ForEach forEach) {
		
	}
	
	override handleForEachCategoryDefinitionStart(ForEach forEach) {
		
	}
	
	override handleForEachBlockEnd(ForEach forEach) {
		
	}
	
	override handleParForEachBlockStart(ParForEach parForEach) {
		
	}
	
	override handleParForEachCategoryDefinitionStart(ParForEach parForEach) {
		
	}
	
	override handleParForEachBlockEnd(ParForEach parForEach) {
		
	}
	
	

}
