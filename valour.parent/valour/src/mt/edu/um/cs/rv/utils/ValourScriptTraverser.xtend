package mt.edu.um.cs.rv.utils

import mt.edu.um.cs.rv.valour.ValourBody
import org.eclipse.emf.ecore.EObject
import mt.edu.um.cs.rv.valour.Declarations

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
	
	def <T extends EObject> T findFirstParentOfType(EObject child, Class<T> parentType){
		if ((child != null) && (parentType.isInstance(child))) {
			return child as T
		}
		else if (child == null){
			return null
		}
		else {
			return findFirstParentOfType(child.eContainer, parentType)
		}
	}
	
}