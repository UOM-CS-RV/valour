package mt.edu.um.cs.rv.utils

import mt.edu.um.cs.rv.valour.ValourBody
import org.eclipse.emf.ecore.EObject
import mt.edu.um.cs.rv.valour.Declarations
import mt.edu.um.cs.rv.valour.StateBlock
import java.util.List
import mt.edu.um.cs.rv.valour.Rule

class ValourScriptTraverser {

	def Declarations findClosestDeclaration(EObject context) {
		if ((context != null) && (context instanceof ValourBody)) {
			
			val declarations = (context as ValourBody).declarations
			if (declarations != null){
				//return the declarations
				return declarations
			}
			else {
				//recurse to try and find higher level declarations
				findClosestDeclaration(context.eContainer)
			}
			
		}

		if (context.eContainer != null) {
			findClosestDeclaration(context.eContainer)
		} else {
			return null
		}
	}
	
	def findParentRule(Rule rule){
		//get parent rule 
		val parentRule = findFirstAncestorOfType(rule.eContainer, Rule)
		
		if (parentRule == null){
			return null
		}
		else if (parentRule.basicRule != null){
			return parentRule.basicRule //this should never happen as basic rule is not nestable
		}
		else if (parentRule.stateBlock != null){
			return parentRule.stateBlock
		}
		else if (parentRule.forEach != null){
			return parentRule.forEach
		}
		else if (parentRule.forEach != null){
			return parentRule.forEach
		}
		else if (parentRule.parForEach != null){
			return parentRule.parForEach
		}
	}
	
	def <T extends EObject> T findFirstAncestorOfType(EObject child, Class<T> ancestorType){
		if ((child != null) && (ancestorType.isInstance(child))) {
			return child as T
		}
		else if (child == null){
			return null
		}
		else {
			return findFirstAncestorOfType(child.eContainer, ancestorType)
		}
	}
	
	def hasAncestorOfType(EObject child, Class ancestorType){
		val ancestor = findFirstAncestorOfType(child, ancestorType)
		ancestor != null
	}
	
	
	def List<? extends EObject> findAllStateBlocksFrom(EObject context){
		//TODO add support for ForEach and ParForEach
		var list = {}
		if ((context != null) && (context instanceof StateBlock)) {
			
			list.addAll(context)
			if (context.eContainer != null) {
				list.addAll(findAllStateBlocksFrom(context))
			} 
			
			return list
		}
	}
	
}