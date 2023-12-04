#Install all the required packages
install.packages('caret')
install.packages('caTools')
install.packages('ROSE')
install.packages('smotefamily')
install.packages('DMwR')
install.packages('rpart')
install.packages('rpart.plot')


#Importing the dataset
credit_card <- read.csv('creditcard_csv.csv')

#Print the structure of the csv file
str(credit_card)

#zero for legitimate cases and one for fraudulent cases
#Convert class to a factor variable
credit_card$Class <- factor(credit_card$Class, levels = c("'0'","'1'"))

#Now we get the summary of the data
summary(credit_card)

#Now we see the stats for the fraud and legit transactions in the dataset.
table(credit_card$Class)
labels <- c("legitimate", "fraud" )
labels <- paste(labels, round(prop.table(table(credit_card$Class))*100,2))
labels <- paste0(labels, "%")

pie(table(credit_card$Class), 
    labels, 
    col=c("green","red"),
    main= "Pie chart of credit card transactions")
#Clearly more than 99.8% of the labels are legitimate.

#-------------------------------------------------------------------------------
#Now first we predict without a model if a transaction is legitimate or not.


predictions <- rep.int("'0'", nrow(credit_card))
predictions <- factor(predictions, levels = c("'0'", "'1'"))

levels(credit_card$Class)
levels(predictions)

library(caret)
confusionMatrix(data = predictions, reference = credit_card$Class)

#-------------------------------------------------------------------------------
#We show using scatter plot that graph is highly skewed in favour of legitimacy.
library(dplyr)

set.seed(1)
credit_card <- credit_card %>% 
  slice_sample(prop = 0.1)

table(credit_card$Class)

library(ggplot2)
ggplot(data = credit_card, aes(x=V1,y=V2,col=Class))+
  geom_point()+
  theme_bw()+
  scale_color_manual(values= c('green','red'))

#-------------------------------------------------------------------------------
#Now we separate the entire dataset into training sets and testing sets
#80 percent is given for training purposes 
#20 percent is given for testing purposes

library(caTools)
set.seed(123)

data_sample =sample.split(credit_card$Class,SplitRatio = 0.8)
train_data =subset(credit_card,data_sample==TRUE)
test_data =subset(credit_card,data_sample==FALSE)

dim(train_data)
dim(test_data)


#-------------------------------------------------------------------------------
# Now to Balance our sample,METHOD 1 : Random oversampling method (ROS)
#-------------------------------------------------------------------------------

table(train_data$Class)
n_legit <- 22749
new_frac_legit <-0.50
new_n_total <- n_legit/new_frac_legit

library(ROSE)
oversampling_result <- ovun.sample(Class ~ . ,
                                   data=train_data,
                                   method="over",
                                   N=new_n_total,
                                   seed=2018)
oversampling_credit <- oversampling_result$data
table(oversampling_credit$Class)

ggplot(data = oversampling_credit, aes(x=V1,y=V2,col=Class))+
  geom_point(position = position_jitter(width=0.1))+
  theme_bw()+
  scale_color_manual(values= c('green','red'))
#clearly observe that Red points overlap with each other ( use jitter to move points )

#-------------------------------------------------------------------------------
# Now to Balance our sample,METHOD 2 : Random undersampling method (RUS)
#-------------------------------------------------------------------------------

table(train_data$Class)
n_fraud <- 35
new_frac_fraud <-0.50
new_n_total <- n_fraud/new_frac_fraud

library(ROSE)
undersampling_result <- ovun.sample(Class ~ . ,
                                   data=train_data,
                                   method="under",
                                   N=new_n_total,
                                   seed=2018)

undersampling_credit <- undersampling_result$data
table(undersampling_credit$Class)

ggplot(data = undersampling_credit, aes(x=V1,y=V2,col=Class))+
  geom_point(position = position_jitter(width=0.1))+
  theme_bw()+
  scale_color_manual(values= c('green','red'))

#-------------------------------------------------------------------------------
# Now to Balance our sample,METHOD 3 : BOTH ROS AND RUS
#-------------------------------------------------------------------------------

table(train_data$Class)
new_frac_frd<-0.50
new_n <- 22749

library(ROSE)
sampling_result <- ovun.sample(Class ~ . ,
                                    data=train_data,
                                    method="both",
                                    N=new_n,
                                    seed=2018)

sampling_credit <- sampling_result$data
table(sampling_credit$Class)
prop.table(table(sampling_credit$Class))*100
ggplot(data = sampling_credit, aes(x=V1,y=V2,col=Class))+
  geom_point(position = position_jitter(width=0.2))+
  theme_bw()+
  scale_color_manual(values= c('green','red'))

#-------------------------------------------------------------------------------
# Now to Balance our sample,METHOD 4 : SMOTE FAMILY METHOD
#-------------------------------------------------------------------------------

library(smotefamily)
library(DMwR)
table(train_data$Class)
n0 <- 22749
n1 <- 35 
r0 <- 0.6

ntimes <- ((1 - r0)/r0)*(n0/n1)-1
smote_output = SMOTE(X=train_data[,-c(1,31)],
                     target = train_data$Class,
                     K=5,
                     dup_size = ntimes)

credit_smote <- smote_output$data
#Change the last name with a upper case "C"
colnames(credit_smote)[30] <- "Class" 
prop.table(table(credit_smote$Class))

#Now we have changed the number of legitimate cases to 60% and fraud cases to 40%

#Original Class distribution
ggplot(train_data, aes(x=V1,y=V2,col=Class))+
  geom_point(position = position_jitter(width=0.2))+
  theme_bw()+
  scale_color_manual(values= c('green','red'))
#SMOTE Class distribution
ggplot(credit_smote, aes(x=V1,y=V2,col=Class))+
  geom_point(position = position_jitter(width=0.2))+
  theme_bw()+
  scale_color_manual(values= c('green','red'))

#-------------------------------------------------------------------------------
#Now we predict the Classes for the test cases using all variables except for 
#Class as independent variables.First we create model called SmoteCARD based on
#Smote data
#-------------------------------------------------------------------------------

library(rpart)
library(rpart.plot)

SmoteCARD_model <- rpart(Class ~ . ,
                    credit_smote) #Create the model on the smote (balanced) data

rpart.plot(SmoteCARD_model,extra =0 ,type =5, tweak =1.1)

#Now we predict the fraud classes

predicted_val <- predict(SmoteCARD_model,test_data,type ='class')

#Now we build a Confusion matrix to check the True '1's of CARDMODEL on smote
library(caret)
confusionMatrix(predicted_val,test_data$Class)



#-------------------------------------------------------------------------------
#Now we predict the Classes for the test cases using all variables except for 
#Class as independent variables.First we create model called OrgCARD based on
#Original data
#-------------------------------------------------------------------------------

library(rpart)
library(rpart.plot)

OrgCARD_model <- rpart(Class ~ . ,
                         train_data[,-1]) #Create the model on the smote (balanced) data

rpart.plot(OrgCARD_model,extra =0 ,type =5, tweak =1.1)

#Now we predict the fraud classes

predicted_val <- predict(OrgCARD_model,test_data,type ='class')

#Now we build a Confusion matrix to check the True '1's of CARDMODEL on smote
library(caret)
confusionMatrix(predicted_val,test_data$Class)

#-------------------------------------------------------------------------------
# Now we compare both the CARD models on the total data and observe the 
# false positive.
#-------------------------------------------------------------------------------
predicted_val <- predict(OrgCARD_model,credit_card[,-1],type ='class')
confusionMatrix(predicted_val,credit_card$Class)

predicted_val <- predict(SmoteCARD_model,credit_card[,-1],type ='class')
confusionMatrix(predicted_val,credit_card$Class)
