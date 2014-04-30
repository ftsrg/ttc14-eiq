package hu.bme.mit.ttc.imdb.transformation

import hu.bme.mit.ttc.imdb.movies.Clique
import hu.bme.mit.ttc.imdb.movies.ContainedElement
import hu.bme.mit.ttc.imdb.movies.Couple
import hu.bme.mit.ttc.imdb.movies.Group
import hu.bme.mit.ttc.imdb.movies.Movie
import hu.bme.mit.ttc.imdb.movies.MoviesFactory
import hu.bme.mit.ttc.imdb.movies.Person
import hu.bme.mit.ttc.imdb.movies.Root
import hu.bme.mit.ttc.imdb.queries.Imdb
import hu.bme.mit.ttc.imdb.transformation.configuration.BenchmarkResults
import java.util.Collection
import java.util.LinkedList
import java.util.List
import java.util.Set
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.incquery.runtime.api.AdvancedIncQueryEngine
import org.eclipse.incquery.runtime.api.IncQueryEngine

class Transformation {

	/**
	 * Initialize the transformation processor on a resource.
	 * The runtime of the transformation steps are logged.
	 * @param r The target resource of the transformation.
	 * @param bmr The benchmark logger.
	 */
	new (Resource r, BenchmarkResults bmr) {
		this.r = r;
		this.bmr = bmr;
		this.root = r.contents.get(0) as Root
	}
	
	protected val BenchmarkResults bmr;
	protected Resource r
	
	////// Resources Management
	protected val Root root;
	/**
	 * Helper function to add elements to the target resource.
	 * @param
	 */
	def addElementToResource(ContainedElement containedElement) {
		root.children.add(containedElement)
	}
	def addElementsToResource(Collection<? extends ContainedElement> containedElements) {
		root.children.addAll(containedElements)
	}
	def getElementsFromResource() {
		root.children
	}
	////////////////////////////
	
	extension MoviesFactory = MoviesFactory.eINSTANCE
	extension Imdb = Imdb.instance

	public def createCouples() {
		bmr.startStopper("createCouples/Engine")
		val engine = AdvancedIncQueryEngine.createUnmanagedEngine(r)
		bmr.endStopper("createCouples/Engine")
		
		bmr.startStopper("createCouples/coupleMatcher")
		val coupleMatcher = engine.personsToCouple
		bmr.endStopper("createCouples/coupleMatcher")
		
		bmr.startStopper("createCouples/commonMoviesMatcher")
		val commonMoviesMatcher = engine.commonMoviesToCouple
		bmr.endStopper("createCouples/commonMoviesMatcher")
		
		bmr.startStopper("createCouples/personNameMatcher")
		val personNameMatcher = engine.personName
		bmr.endStopper("createCouples/personNameMatcher")
		
		bmr.startStopper("createCouples/transformation")
		val newCouples = new LinkedList<Couple>
		coupleMatcher.forEachMatch [
			val couple = createCouple()
			val p1 = personNameMatcher.getAllValuesOfp(p1name).head
			val p2 = personNameMatcher.getAllValuesOfp(p2name).head
			couple.setP1(p1)
			couple.setP2(p2)
			val commonMovies = commonMoviesMatcher.getAllValuesOfm(p1name, p2name)
			couple.commonMovies.addAll(commonMovies)
				
			newCouples += couple
		]
		bmr.endStopper("createCouples/transformation")
		
		println("# of couples = " + newCouples.size)
		
		bmr.startStopper("createCouples/dispose")
		engine.dispose
		bmr.endStopper("createCouples/dispose")
		
		bmr.startStopper("createCouples/adding")
		addElementsToResource(newCouples);
		bmr.endStopper("createCouples/adding")
	}

	def topGroupByRating(int size) {
		println("Top-15 by Average Rating")
		println("========================")
		val n = 15;
		
		bmr.startStopper("AVG/Engine")
		val engine = IncQueryEngine.on(r)
		bmr.endStopper("AVG/Engine")
		
		bmr.startStopper("AVG/matcher")
		val coupleWithRatingMatcher = engine.groupSize
		bmr.endStopper("AVG/matcher")
		
		bmr.startStopper("AVG/Sort")
		val rankedCouples = coupleWithRatingMatcher.getAllValuesOfgroup(size).sort(
			new GroupAVGComparator)
		bmr.endStopper("AVG/Sort")

		printCouples(n, rankedCouples)
	}

	def topGroupByCommonMovies(int size) {
		println("Top-15 by Number of Common Movies")
		println("=================================")

		val n = 15;
		val engine = IncQueryEngine.on(r)
		
		bmr.startStopper("Movies/matcher")
		val coupleWithRatingMatcher = engine.groupSize
		bmr.endStopper("Movies/matcher")
		
		bmr.startStopper("Movies/Sort")
		val rankedCouples = coupleWithRatingMatcher.getAllValuesOfgroup(size).sort(
			new GroupSizeComparator
		)
		bmr.endStopper("Movies/Sort")

		printCouples(n, rankedCouples)
	}

	def printCouples(int n, List<Group> rankedCouples) {
		(0 .. n - 1).forEach [
			if(it < rankedCouples.size) {
				val c = rankedCouples.get(it);
				println(c.printGroup(it + 1))
			}
		]
	}
	
	def printGroup(Group group, int lineNumber) {
		if(group instanceof Couple) {
			val couple = group as Couple
			return '''«lineNumber». Couple avgRating «group.avgRating», «group.commonMovies.size» movies («couple.p1.name»; «couple.p2.name»)'''
		}
		else {
			val clique = group as Clique
			return '''«lineNumber». «clique.persons.size»-Clique avgRating «group.avgRating», «group.commonMovies.size» movies («
				FOR person : clique.persons SEPARATOR ", "»«person.name»«ENDFOR»)'''
		}
	}
	
	def calculateAvgRatings() {
		bmr.startStopper("avg")
		getElementsFromResource.filter(typeof(Group)).forEach[x|calculateAvgRating(x.commonMovies, x)]
		bmr.endStopper("avg")
	}

	protected def calculateAvgRating(Collection<Movie> commonMovies, Group group) {
		var sumRating = 0.0

		for (m : commonMovies) {
			sumRating = sumRating + m.rating
		}
		val n = commonMovies.size
		group.avgRating = sumRating / n
	}

	public def createCliques(int cliques) {
		bmr.startStopper("createClique/Engine")
		val engine = AdvancedIncQueryEngine.createUnmanagedEngine(r)
		bmr.endStopper("createClique/Engine")
		
		bmr.startStopper("createClique/personMatcher")
		val personMatcher = getPersonName(engine)
		bmr.endStopper("createClique/personMatcher")
		
		var Collection<Clique> newCliques
		
		if(cliques == 3) {
			bmr.startStopper("createClique/3engine")
			val clique3 = getPersonsTo3Clique(engine)
			bmr.endStopper("createClique/3engine")
			
			bmr.startStopper("createClique/cliqueGeneration")
			newCliques = clique3.allMatches.map[x|generateClique(
				personMatcher.getOneArbitraryMatch(null,x.p1).p,
				personMatcher.getOneArbitraryMatch(null,x.p2).p,
				personMatcher.getOneArbitraryMatch(null,x.p3).p)].toList;
			bmr.endStopper("createClique/cliqueGeneration")
			
		}
		else if(cliques == 4) {
			bmr.startStopper("createClique/4engine")
			val clique4 = getPersonsTo4Clique(engine)
			bmr.endStopper("createClique/4engine")
			
			bmr.startStopper("createClique/cliqueGeneration")
			newCliques = clique4.allMatches.map[x|generateClique(
				personMatcher.getOneArbitraryMatch(null,x.p1).p,
				personMatcher.getOneArbitraryMatch(null,x.p2).p,
				personMatcher.getOneArbitraryMatch(null,x.p3).p,
				personMatcher.getOneArbitraryMatch(null,x.p4).p)].toList;
			bmr.endStopper("createClique/cliqueGeneration")
		}
		else if(cliques == 5) {
			bmr.startStopper("createClique/5engine")
			val clique5 = getPersonsTo5Clique(engine)
			bmr.endStopper("createClique/5engine")
			
			bmr.startStopper("createClique/cliqueGeneration")
			newCliques = clique5.allMatches.map[x|generateClique(
				personMatcher.getOneArbitraryMatch(null,x.p1).p,
				personMatcher.getOneArbitraryMatch(null,x.p2).p,
				personMatcher.getOneArbitraryMatch(null,x.p3).p,
				personMatcher.getOneArbitraryMatch(null,x.p4).p,
				personMatcher.getOneArbitraryMatch(null,x.p5).p)].toList;
			bmr.endStopper("createClique/cliqueGeneration")
		}
		
		println("# of "+cliques+"-cliques = " + newCliques.size)
		
		bmr.startStopper("createClique/dispose")
		engine.dispose
		bmr.endStopper("createClique/dispose")
		
		bmr.startStopper("createClique/commonMovies")
		newCliques.forEach[x|x.commonMovies.addAll(x.collectCommonMovies)]
		bmr.endStopper("createClique/commonMovies")
		
		bmr.startStopper("createClique/adding")
		addElementsToResource(newCliques);
		bmr.endStopper("createClique/adding")
	}
	
	protected def generateClique(Person... persons) {
		val c = createClique
		c.persons += persons
		return c
	}
	
	protected def collectCommonMovies(Clique clique) {
		var Set<Movie> commonMovies = null;
		for(personMovies : clique.persons.map[movies]) {
			if(commonMovies == null) {
				commonMovies = personMovies.toSet;
			}
			else {
				commonMovies.retainAll(personMovies)
			}
		}
		return commonMovies
	}
}
