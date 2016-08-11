package mt.edu.um.cs.rv.jvmmodel.handler;

import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import mt.edu.um.cs.rv.valour.Model
import org.eclipse.xtext.xtype.XImportSection
import mt.edu.um.cs.rv.valour.Category
import mt.edu.um.cs.rv.valour.Event
import mt.edu.um.cs.rv.valour.FormalParameters
import mt.edu.um.cs.rv.valour.EventTrigger
import mt.edu.um.cs.rv.valour.ControlFlowTrigger
import mt.edu.um.cs.rv.valour.MonitorTrigger
import mt.edu.um.cs.rv.valour.EventBody
import mt.edu.um.cs.rv.valour.WhereClauses
import mt.edu.um.cs.rv.valour.WhereClause
import mt.edu.um.cs.rv.valour.WhenClause
import mt.edu.um.cs.rv.valour.CategorisationClause
import mt.edu.um.cs.rv.valour.Condition
import mt.edu.um.cs.rv.valour.Action
import mt.edu.um.cs.rv.valour.Rule
import mt.edu.um.cs.rv.valour.BasicRule
import mt.edu.um.cs.rv.valour.StateBlock
import mt.edu.um.cs.rv.valour.ActualParameters
import mt.edu.um.cs.rv.valour.StateDeclaration
import mt.edu.um.cs.rv.valour.ForEach
import mt.edu.um.cs.rv.valour.ParForEach
import org.eclipse.xtext.xbase.jvmmodel.AbstractModelInferrer
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.xbase.jvmmodel.JvmTypeReferenceBuilder
import com.google.inject.Inject
import org.eclipse.xtext.xbase.jvmmodel.JvmAnnotationReferenceBuilder

public abstract class InferrerHandler {	
	
	def void setup(JvmAnnotationReferenceBuilder _annotationTypesBuilder, JvmTypeReferenceBuilder _typeReferenceBuilder){}
	
	def void initialise(Model model, IJvmDeclaredTypeAcceptor acceptor)
	
	def void handleImports(XImportSection imports);
	
	def void handleDeclarationsBlockStart();
	
	def void handleDeclarationsBlockEnd();
	
	def void handleCategoryDeclaration(Category category)
	
	
	def void handleEventDeclarationBegin(Event event)
	def void handleControlFlowTrigger(ControlFlowTrigger controlFlowTrigger, Boolean additionalTrigger) 
	def void handleEventTrigger(EventTrigger eventTrigger, Boolean additionalTrigger)
	def void handleMonitorTrigger(MonitorTrigger monitorTrigger, Boolean additionalTrigger)
	def void handleEventDeclarationEnd(Event event)	
	def void handleWhereClausesStart(WhereClauses whereClauses) 
	def void handleWhereClausesEnd(WhereClauses whereClauses)
	def void handleWhereClause(WhereClause whereClause)
	def void handleWhenClauseStart(WhenClause whenClause)
	def void handleWhenClauseEnd(WhenClause whenClause)
	def void handleWhenClauseExpression(WhenClause clause) 

	def void handleCategorisationClauseStart(CategorisationClause categorisationClause)
	def void handleCategorisationClauseExpression(CategorisationClause categorisationClause)
	def void handleCategorisationClauseEnd(CategorisationClause categorisationClause)
	
	
	def void handleConditionDeclarationStart(Condition condition)
	def void handleConditionDeclarationExpression(Condition condition)
	def void handleConditionDeclarationEnd(Condition condition)
	
	def void handleActionDeclarationStart(Action action)
	def void handleActionDeclarationActionBlock(Action action)
	def void handleActionDeclarationEnd(Action action)
	
	def void handleRuleStart(Rule rule)
	def void handleBasicRule(BasicRule basicRule)
	def void handleRuleEnd(Rule rule)
	
	def void handleStateBlockStart(StateBlock block)
	def void handleStateDeclaration(StateDeclaration sd)
	def void handleStateBlockStateDeclarationsEnd(StateBlock block)
	def void handleStateBlockEnd(StateBlock block)
	
	def void handleForEachBlockStart(ForEach forEach)
	def void handleForEachCategoryDefinitionStart(ForEach forEach)
	def void handleForEachBlockEnd(ForEach forEach)
	
	
	def void handleParForEachBlockStart(ParForEach parForEach)
	def void handleParForEachCategoryDefinitionStart(ParForEach parForEach)
	def void handleParForEachBlockEnd(ParForEach parForEach)
	
	def String formalParametersAsString(FormalParameters fps) {
		var s = ""
		if (fps != null) {
			var fpsSize = fps.parameters.length
			for (fp : fps.parameters) {
				s = s + fp.parameterType.qualifiedName + ' ' + fp.name
				fpsSize--;
				if (fpsSize > 0) {
					s = s + ', '
				}
			}
		}
		return s

	}
	
	def String actualParametersAsString(ActualParameters aps) {
		var s = ""

		if (aps != null) {
			var apsSize = aps.parameters.length
			for (ap : aps.parameters) {
				s = s + ap.toString
				apsSize--;
				if (apsSize > 0) {
					s = s + ', '
				}
			}
		}

		return s
	}
}
