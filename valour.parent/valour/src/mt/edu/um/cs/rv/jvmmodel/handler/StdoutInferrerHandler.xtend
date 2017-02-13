package mt.edu.um.cs.rv.jvmmodel.handler;

import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import mt.edu.um.cs.rv.valour.Model
import org.eclipse.xtext.xtype.XImportSection
import mt.edu.um.cs.rv.valour.Category
import mt.edu.um.cs.rv.valour.Event
import mt.edu.um.cs.rv.valour.FormalParameters
import mt.edu.um.cs.rv.valour.EventBody
import mt.edu.um.cs.rv.valour.SimpleTrigger
import mt.edu.um.cs.rv.valour.ControlFlowTrigger
import mt.edu.um.cs.rv.valour.EventTrigger
import mt.edu.um.cs.rv.valour.MonitorTrigger
import mt.edu.um.cs.rv.valour.WhereClauses
import mt.edu.um.cs.rv.valour.WhereClause
import mt.edu.um.cs.rv.valour.ValueExpression
import org.eclipse.emf.common.util.EList
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import mt.edu.um.cs.rv.valour.WhenClause
import mt.edu.um.cs.rv.valour.ConditionExpression
import mt.edu.um.cs.rv.valour.ConditionRefInvocation
import mt.edu.um.cs.rv.valour.ActualParameters
import mt.edu.um.cs.rv.valour.CategorisationClause
import mt.edu.um.cs.rv.valour.Condition
import mt.edu.um.cs.rv.valour.Action
import mt.edu.um.cs.rv.valour.ActionBlock
import mt.edu.um.cs.rv.valour.Rule
import mt.edu.um.cs.rv.valour.BasicRule
import mt.edu.um.cs.rv.valour.StateBlock
import mt.edu.um.cs.rv.valour.StateDeclaration
import mt.edu.um.cs.rv.valour.ForEach
import mt.edu.um.cs.rv.valour.ParForEach
import mt.edu.um.cs.rv.valour.ExternalTrigger

public class StdoutInferrerHandler extends InferrerHandler {

	override initialise(Model model, IJvmDeclaredTypeAcceptor acceptor) {
		// nothing is required here
	}

	override handleImports(XImportSection imports) {
		if (imports != null) {
			for (i : imports.importDeclarations) {
				println('import ' + i.importedName)
			}
		}
	}

	override handleDeclarationsBlockStart() {
		println("declarations {")
	}

	override handleDeclarationsBlockEnd() {
		println("}")
		println
	}

	override handleCategoryDeclaration(Category category) {
		println('category ' + category.name + ' indexed by ' + category.keyType.qualifiedName)
	}

	override handleEventDeclarationBegin(Event event) {
		val eventDecName = event.name + ' (' + formalParametersAsString(event.eventFormalParameters) + ')'
		println('event ' + eventDecName + ' = {')
	}

	override handleControlFlowTrigger(ControlFlowTrigger controlFlowTrigger, Boolean additionalTrigger) {
		if (additionalTrigger) {
			println()
			print('\t|| ')
		}
		println('system controlflow trigger \"' + controlFlowTrigger.aop.expression + '\"')
	}

	override handleMonitorTrigger(MonitorTrigger monitorTrigger, Boolean additionalTrigger) {
		if (additionalTrigger) {
			println()
			print('\t|| ')
		}
		println('monitor trigger ' + monitorTrigger.name + ' (' + formalParametersAsString(monitorTrigger.params) + ')')

	}

	override handleEventTrigger(EventTrigger eventTrigger, Boolean additionalTrigger) {
		if (additionalTrigger) {
			println()
			print('\t|| ')
		}
		println('event trigger ' + eventTrigger.onEvent + ' (' + formalParametersAsString(eventTrigger.params) + ')')
	}
	
	override handleExternaTrigger(ExternalTrigger externalTrigger, Boolean additionalTrigger) {
		if (additionalTrigger) {
			println()
			print('\t|| ')
		}
		println('external trigger ' + externalTrigger.triggerClass.qualifiedName + ' generates ' + externalTrigger.dataClass.qualifiedName)
	
	}

	override handleEventDeclarationEnd(Event event) {
		println('}')
	}

	override handleWhereClausesStart(WhereClauses whereClauses) {
		print('where ')
	}

	override handleWhereClausesEnd(WhereClauses whereClauses) {
		println
	}

	override handleWhereClause(WhereClause whereClause) {
		print(whereClause.whereId + " = ")
		handleValueExpression(whereClause.whereExpression)
	}

	def void handleValueExpression(ValueExpression ve) {

		if (ve.simple != null) {
			handleValueBlockStatements('{{', '}}', ve.simple.expressions)
		} else {
			handleValueBlockStatements('{', '}', ve.complex.expressions)
		}
	}

	def handleValueBlockStatements(String openBraces, String closeBraces, EList<XExpression> expressions) {
		println(openBraces)
		for (e : expressions) {
			println(NodeModelUtils.getNode(e).text)
		}
		println(closeBraces)
	}

	override handleWhenClauseStart(WhenClause whenClause) {
		print('when ')
	}

	override handleWhenClauseExpression(WhenClause whenClause) {
		val conditionExpression = whenClause.condition

		handleConditionExpression(conditionExpression)
	}
	
	def void handleConditionExpression(ConditionExpression conditionExpression){
		if (conditionExpression.ref != null) {
			// handle reference to condition
			handleConditionRefInvocation(conditionExpression.ref as ConditionRefInvocation)
		} else {
			val conditionBlock = conditionExpression.block
			if (conditionBlock.simple != null) {
				handleConditionBlockStatements('{{', '}}', conditionBlock.simple.expressions)
			} else {
				handleConditionBlockStatements('{', '}', conditionBlock.complex.expressions)
			}
		}
	}

	def void handleConditionRefInvocation(ConditionRefInvocation cri) {
		print('#' + cri.ref.ref.name + '(')
		print(actualParametersAsString(cri.params))
		print(')')
	}

	def handleConditionBlockStatements(String openBraces, String closeBraces, EList<XExpression> expressions) {
		println(openBraces)
		for (e : expressions) {
			// TODO check whether ConditionRefInvocation is being handled correctly
			println(NodeModelUtils.getNode(e).text)
		}
		println(closeBraces)
	}

	override handleWhenClauseEnd(WhenClause whenClause) {
		println
	}
	
	
	
	override handleCategorisationClauseStart(CategorisationClause categorisationClause) {
		print('belonging to ' + categorisationClause.category.category.name + ' with index ')
	}
	
	override handleCategorisationClauseExpression(CategorisationClause categorisationClause) {
		handleValueExpression(categorisationClause.categoryExpression)
	}
	
	override handleCategorisationClauseEnd(CategorisationClause categorisationClause) {
		println
	}
	
	
	override handleConditionDeclarationStart(Condition condition) {
		val conditionDec = 'condition ' + condition.name + ' (' 
					+ formalParametersAsString(condition.conditionFormalParameters) 
					+ ') = '
					
		println(conditionDec)
	}
	
	override handleConditionDeclarationExpression(Condition condition) {
		handleConditionExpression(condition.conditionExpression)
	}
	
	override handleConditionDeclarationEnd(Condition condition) {
		println()
	}
	
	
	override handleActionDeclarationStart(Action action) {
		val actionDec = 'action ' + action.name + ' (' 
					+ formalParametersAsString(action.actionFormalParameters) 
					+ ') = '
					
		println(actionDec)
	}
	
	override handleActionDeclarationActionBlock(Action action) {
		handleActionBlock(action.action as ActionBlock) // TODO not sure whether there is a better way of doing this (i.e. not with a type cast)
	}
	
	override handleActionDeclarationEnd(Action Action) {
		println()
	}
	
	
	def void handleActionBlock(ActionBlock ab) {
		println('{')
		for (e : ab.expressions) {
			// TODO check whether ActionRefInvocation is being handled correctly
			println(NodeModelUtils.getNode(e).text)
		}
		println('}')
	}
	
	override handleRuleStart(Rule rule) {
		
	}
	
	override handleBasicRule(BasicRule basicRule) {
		print( 
					basicRule.event.eventRefId.name 
					+ "(" + actualParametersAsString(basicRule.event.eventActualParameters) + ") ")

		if (basicRule.condition != null) {
			print(' | ')
			handleConditionExpression(basicRule.condition)
		}

		print(' -> ')
	
		val ruleAction = basicRule.ruleAction

		if (ruleAction.actionBlock != null) {
			handleActionBlock(ruleAction.actionBlock as ActionBlock)
		} else if (ruleAction.actionRefInvocation != null) {
			print('#')
			print(ruleAction.actionRefInvocation.actionRef.actionRefId.name)
			print('(')
			actualParametersAsString(ruleAction.actionRefInvocation.actionActualParameters)
			println(')')
		} else {
			// action monitor trigger fire
			print('#generate trigger')
			print(ruleAction.actionMonitorTriggerFire.monitorTrigger)
			print('(')
			actualParametersAsString(ruleAction.actionMonitorTriggerFire.monitorTriggerActualParameters)
			println(')')
		}

	}
	
	override handleRuleEnd(Rule rule) {
		println()
	}
	
	override handleStateBlockStart(StateBlock block) {
		println('state {')
	}
	
	override handleStateDeclaration(StateDeclaration sd) {
		print(sd.type.qualifiedName + ' ')
		print(sd.name + ' = ')
		handleValueExpression(sd.valueExpression)
		println
	}
	
	override handleStateBlockStateDeclarationsEnd(StateBlock block) {
		println('} in {')
	}
	
	override handleStateBlockEnd(StateBlock block) {
		println('}')
	}
	
	override handleForEachBlockStart(ForEach forEach) {
		println('replicate {')
	}
	
	override handleForEachCategoryDefinitionStart(ForEach forEach) {
		println('} foreach ' + forEach.category.category.name + ' ' + forEach.categoryLabel + '{ ')
	}
	
	override handleForEachBlockEnd(ForEach forEach) {
		println('}')
	}
	
	
	override handleParForEachBlockStart(ParForEach parForEach) {
		println('replicate in parallel {')
	}
	
	override handleParForEachCategoryDefinitionStart(ParForEach parForEach) {
		println('} foreach ' + parForEach.category.category.name + ' ' + parForEach.categoryLabel + '{ ')
	}
	
	override handleParForEachBlockEnd(ParForEach parForEach) {
		println('}')
	}

	override handleScriptEnd(Model model) {
		//nothing to do
	}
	
}
