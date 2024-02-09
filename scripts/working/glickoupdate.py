import time
import datetime

startTime = time.time()

import os
import math
import json
import pyodbc

TAU = 0.5  # System constant

class Player:

	# The system constant, which constrains
	# the change in volatility over time.
	TAU = 0.5

	def getRating(self):
		return (self.__rating * 173.7178) + 1500 

	def setRating(self, rating):
		self.__rating = (rating - 1500) / 173.7178

	rating = property(getRating, setRating)

	def getRd(self):
		return self.__rd * 173.7178

	def setRd(self, rd):
		self.__rd = rd / 173.7178

	rd = property(getRd, setRd)
	 
	def __init__(self, rating = 1500, rd = 350, vol = 0.06):
		# For testing purposes, preload the values
		# assigned to an unrated player.
		self.setRating(rating)
		self.setRd(rd)
		self.vol = vol
			
	def _preRatingRD(self):
		""" Calculates and updates the player's rating deviation for the
		beginning of a rating period.
		
		preRatingRD() -> None
		
		"""
		self.__rd = math.sqrt(math.pow(self.__rd, 2) + math.pow(self.vol, 2))
		
	def update_player(self, rating_list, RD_list, outcome_list):
		""" Calculates the new rating and rating deviation of the player.
		
		update_player(list[int], list[int], list[bool]) -> None
		
		"""
		# Convert the rating and rating deviation values for internal use.
		rating_list = [(x - 1500) / 173.7178 for x in rating_list]
		RD_list = [x / 173.7178 for x in RD_list]

		v = self._v(rating_list, RD_list)
		self.vol = self._newVol(rating_list, RD_list, outcome_list, v)
		self._preRatingRD()
		
		self.__rd = 1 / math.sqrt((1 / math.pow(self.__rd, 2)) + (1 / v))
		
		tempSum = 0
		for i in range(len(rating_list)):
			tempSum += self._g(RD_list[i]) * (outcome_list[i] - self._E(rating_list[i], RD_list[i]))
		self.__rating += math.pow(self.__rd, 2) * tempSum
		
	#step 5        
	def _newVol(self, rating_list, RD_list, outcome_list, v):
		""" Calculating the new volatility as per the Glicko2 system. 
		
		Updated for Feb 22, 2012 revision. -Leo
		
		_newVol(list, list, list, float) -> float
		
		"""
		#step 1
		a = math.log(self.vol**2)
		eps = 0.000001
		A = a
		
		#step 2
		B = None
		delta = self._delta(rating_list, RD_list, outcome_list, v)
		tau = self.TAU
		if (delta ** 2)  > ((self.__rd**2) + v):
			B = math.log(delta**2 - self.__rd**2 - v)
		else:        
			k = 1
			while self._f(a - k * math.sqrt(tau**2), delta, v, a) < 0:
				k = k + 1
			B = a - k * math.sqrt(tau **2)
		
		#step 3
		fA = self._f(A, delta, v, a)
		fB = self._f(B, delta, v, a)
		
		#step 4
		while math.fabs(B - A) > eps:
			#a
			C = A + ((A - B) * fA)/(fB - fA)
			fC = self._f(C, delta, v, a)
			#b
			if fC * fB <= 0:
				A = B
				fA = fB
			else:
				fA = fA/2.0
			#c
			B = C
			fB = fC
		
		#step 5
		return math.exp(A / 2)
		
	def _f(self, x, delta, v, a):
		ex = math.exp(x)
		num1 = ex * (delta**2 - self.__rating**2 - v - ex)
		denom1 = 2 * ((self.__rating**2 + v + ex)**2)
		return  (num1 / denom1) - ((x - a) / (self.TAU**2))
		
	def _delta(self, rating_list, RD_list, outcome_list, v):
		""" The delta function of the Glicko2 system.
		
		_delta(list, list, list) -> float
		
		"""
		tempSum = 0
		for i in range(len(rating_list)):
			tempSum += self._g(RD_list[i]) * (outcome_list[i] - self._E(rating_list[i], RD_list[i]))
		return v * tempSum
		
	def _v(self, rating_list, RD_list):
		""" The v function of the Glicko2 system.
		
		_v(list[int], list[int]) -> float
		
		"""
		tempSum = 0
		for i in range(len(rating_list)):
			tempE = self._E(rating_list[i], RD_list[i])
			tempSum += math.pow(self._g(RD_list[i]), 2) * tempE * (1 - tempE)
		return 1 / tempSum
		
	def _E(self, p2rating, p2RD):
		""" The Glicko E function.
		
		_E(int) -> float
		
		"""
		return 1 / (1 + math.exp(-1 * self._g(p2RD) * (self.__rating - p2rating)))
		
	def _g(self, RD):
		""" The Glicko2 g(RD) function.
		
		_g() -> float
		
		"""
		return 1 / math.sqrt(1 + 3 * math.pow(RD, 2) / math.pow(math.pi, 2))
		
	def did_not_compete(self):
		""" Applies Step 6 of the algorithm. Use this for
		players who did not compete in the rating period.

		did_not_compete() -> None
		
		"""
		self._preRatingRD()

def currentTime():
	return datetime.datetime.strftime(datetime.datetime.now(), "%Y-%m-%d %H:%M:%S")

def loadSQL():
	sql = {}
	sqlPath = "./scripts/sql/glickoupdate"

	if os.path.exists(sqlPath):
		for file in os.listdir(sqlPath):
			with open(f"{ sqlPath }/{ file }", "r") as fileReader:
				sql[os.path.splitext(file)[0]] = fileReader.read()
	
	return sql

# Calculate the Glicko-2 scale
def scale(phi):
	return 1 / math.sqrt(1 + 3 * phi**2 / math.pi**2)

def calculateProbaility(rating1, rating2, rd1, rd2):

	# Calculate the expected outcome for each player
	expected1 = 1 / (1 + math.exp(-TAU * scale(rd2) * (rating1 - rating2)))
	expected2 = 1 / (1 + math.exp(-TAU * scale(rd1) * (rating2 - rating1)))

	# Calculate the win probability for Player 1
	winProbability = expected1 / (expected1 + expected2)

	return winProbability

def processBatch(matches):
	wrestlerIds = list(set([ match.TSWrestlerID for match in matches ]))

	wrestlers = []
	for wrestlerId in wrestlerIds:
		wrestlerMatches = [ match for match in matches if match.TSWrestlerID == wrestlerId ]

		wrestlers.append({
			"wrestlerId": wrestlerId,
			"glicko": Player(rating = float(wrestlerMatches[0].Rating), rd = float(wrestlerMatches[0].Deviation), vol = float(wrestlerMatches[0].Volatility)),
			"matches": [ { "matchId": match.TSMatchID, "probability": calculateProbaility(float(wrestlerMatches[0].Rating), float(match.OpponentRating), float(wrestlerMatches[0].Deviation), float(match.OpponentDeviation))} for match in wrestlerMatches if match.TSMatchID is not None ],
			"matchRatings": [ float(match.OpponentRating) for match in wrestlerMatches if match.TSMatchID is not None ],
			"matchDeviations": [ float(match.OpponentDeviation) for match in wrestlerMatches if match.TSMatchID is not None ],
			"matchOutcomes": [ float(match.MatchResult) for match in wrestlerMatches if match.TSMatchID is not None ],
		})

	return wrestlers

print(f"{ currentTime() }: ----------- Setup")

print(f"{ currentTime() }: Load config")

with open("./scripts/config.json", "r") as reader:
	config = json.load(reader)

millDBURL = config["millServer"]

sql = loadSQL()

print(f"{ currentTime() }: DB connect")

cn = pyodbc.connect(f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={ config['database']['server'] };DATABASE={ config['database']['database'] };ENCRYPT=no;UID={ config['database']['user'] };PWD={ config['database']['password'] }", autocommit=True)
cur = cn.cursor()

print(f"{ currentTime() }: ----------- Begin")

print(f"{ currentTime() }: Initialize")

cur.execute(sql["MatchInitialize"], (1500.0, 350.0, 0.06))
batchCount = cur.fetchval()
batchIndex = 0

cur.execute(sql["MatchBatch"])
batchData = cur.fetchall()

wrestlers = processBatch(batchData)

while len(wrestlers) > 0:
	batchIndex += 1
	print(f"{ currentTime() }: Total: { batchCount }, current { batchIndex }, queue: { batchCount - batchIndex }")

	cur.execute(sql["StageCreate"])

	for wrestler in wrestlers:
		if len(wrestler["matches"]) > 0:

			wrestler["glicko"].update_player(wrestler["matchRatings"], wrestler["matchDeviations"], wrestler["matchOutcomes"])
			cur.executemany(sql["StageLoad"], [ [ wrestler["wrestlerId"], match["matchId"], match["probability"], wrestler["glicko"].rating, wrestler["glicko"].rd, wrestler["glicko"].vol ] for match in wrestler["matches"] ])

		else:

			wrestler["glicko"].did_not_compete()
			cur.executemany(sql["StageLoad"], [ [ wrestler["wrestlerId"], None, None, wrestler["glicko"].rating, wrestler["glicko"].rd, wrestler["glicko"].vol ] ])

	cur.execute(sql["StageUpdate"])
	
	cur.execute(sql["MatchBatch"])
	batchData = cur.fetchall()
	wrestlers = processBatch(batchData)

cur.close()
cn.close()

print(f"{ currentTime() }: ----------- End")
